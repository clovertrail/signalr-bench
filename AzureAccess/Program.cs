using CommandLine;
using Microsoft.Azure.Management.Compute.Fluent;
using Microsoft.Azure.Management.Compute.Fluent.Models;
using Microsoft.Azure.Management.Fluent;
using Microsoft.Azure.Management.Network.Fluent;
using Microsoft.Azure.Management.Network.Fluent.Models;
using Microsoft.Azure.Management.ResourceManager.Fluent;
using Microsoft.Azure.Management.ResourceManager.Fluent.Core;
using Microsoft.Azure.Management.ResourceManager.Fluent.Core.ResourceActions;
using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Text;
using System.Threading;
using System.Threading.Tasks;

namespace VMAccess
{
    class Program
    {
        static void Main(string[] args)
        {
            CreateVM(args);
        }

        static void CheckInputArgs(string[] args)
        {
            bool invalidOptions = false;
            // parse args
            var agentConfig = new ArgsOption();
            var result = Parser.Default.ParseArguments<ArgsOption>(args)
                .WithParsed(options => agentConfig = options)
                .WithNotParsed(error => {
                    Console.WriteLine($"Fail to parse the options: {error}");
                    invalidOptions = true;
                });
            if (invalidOptions)
            {
                return;
            }
            if (agentConfig.BenchClientListFile != null)
            {
                Util.Log($"Bench client output file: {agentConfig.BenchClientListFile}");
            }
            if (agentConfig.VMHostFile != null)
            {
                Util.Log($"VM host output file: {agentConfig.VMHostFile}");
            }
            Util.Log($"auth file: {agentConfig.AuthFile}");
            var credentials = SdkContext.AzureCredentialsFactory
                .FromFile(agentConfig.AuthFile);
            var azure = Azure
                .Configure()
                .WithLogLevel(HttpLoggingDelegatingHandler.Level.Basic)
                .Authenticate(credentials)
                .WithDefaultSubscription();
            var img = azure.VirtualMachineCustomImages.GetByResourceGroup(agentConfig.ImgResourceGroup, agentConfig.ImgName);
            Util.Log($"Customized image id: {img.Id}");

            var region = img.Region;
            Util.Log($"target region: {region.Name}");
            var VmSize = VirtualMachineSizeTypes.Parse(agentConfig.VmSize);
            Util.Log($"VM size: {VmSize}");
            var sshPubKey = System.IO.File.ReadAllText(agentConfig.SshPubKeyFile);
            Util.Log($"SSH public key: {sshPubKey}");
            Util.Log($"Accelerated Network: {agentConfig.AcceleratedNetwork}");
        }

        static void CreateVM(string[] args)
        {
            bool invalidOptions = false;
            // parse args
            var agentConfig = new ArgsOption();
            var result = Parser.Default.ParseArguments<ArgsOption>(args)
                .WithParsed(options => agentConfig = options)
                .WithNotParsed(error => {
                    Console.WriteLine($"Fail to parse the options: {error}");
                    invalidOptions = true;
                });
            if (invalidOptions)
            {
                return;
            }

            var sw = new Stopwatch();
            sw.Start();

            // auth file
            Util.Log($"auth file: {agentConfig.AuthFile}");
            var credentials = SdkContext.AzureCredentialsFactory
                .FromFile(agentConfig.AuthFile);

            //var credentials = SdkContext.AzureCredentialsFactory.FromServicePrincipal(clientId:, clientSecret:, tenantId:, environment:AzureEnvironment.AzureGlobalCloud)
            var azure = Azure
                .Configure()
                .WithLogLevel(HttpLoggingDelegatingHandler.Level.Basic)
                .Authenticate(credentials)
                .WithDefaultSubscription();
            var img = azure.VirtualMachineCustomImages.GetByResourceGroup(agentConfig.ImgResourceGroup, agentConfig.ImgName);
            Util.Log($"Customized image id: {img.Id}");

            var region = img.Region;
            Util.Log($"target region: {region.Name}");

            var VmSize = VirtualMachineSizeTypes.Parse(agentConfig.VmSize);
            Util.Log($"VM size: {VmSize}");

            var sshPubKey = System.IO.File.ReadAllText(agentConfig.SshPubKeyFile);
            Util.Log($"SSH public key: {sshPubKey}");
            Util.Log($"Accelerated Network: {agentConfig.AcceleratedNetwork}");

            var resourceGroupName = agentConfig.ResourceGroup;
            IResourceGroup resourceGroup = null;
            if (!azure.ResourceGroups.Contain(resourceGroupName))
            {
                resourceGroup = azure.ResourceGroups.Define(resourceGroupName)
                    .WithRegion(region)
                    .Create();
            }

            // create virtual net
            Util.Log("Creating virtual network...");
            var subNetName = agentConfig.Prefix + "Subnet";
            var network = azure.Networks.Define(agentConfig.Prefix + "VNet")
                .WithRegion(region)
                .WithExistingResourceGroup(resourceGroupName)
                .WithAddressSpace("10.0.0.0/16")
                .WithSubnet(subNetName, "10.0.0.0/24")
                .Create();

            // Prepare a batch of Creatable Virtual Machines definitions
            var creatableVirtualMachines = new List<ICreatable<IVirtualMachine>>();

            // create vms
            var publicIpTaskList = new List<Task<IPublicIPAddress>>();
            Util.Log("Creating public IP address...");
            for (var i = 0; i < agentConfig.VmCount; i++)
            {
                // create public ip
                var publicIPAddress = azure.PublicIPAddresses.Define(agentConfig.Prefix + Convert.ToString(i) + "PubIP")
                    .WithRegion(region)
                    .WithExistingResourceGroup(resourceGroupName)
                    .WithLeafDomainLabel(agentConfig.Prefix + Convert.ToString(i))
                    .WithDynamicIP()
                    .CreateAsync();
                publicIpTaskList.Add(publicIPAddress);
            }
            Task.WaitAll(publicIpTaskList.ToArray());
            Util.Log("Finish creating public IP address...");

            Util.Log($"Creating network security group...");
            var nsgTaskList = new List<Task<INetworkSecurityGroup>>();
            for (var i = 0; i < agentConfig.VmCount; i++)
            {
                var nsg = azure.NetworkSecurityGroups.Define(agentConfig.Prefix + Convert.ToString(i) + "NSG")
                    .WithRegion(region)
                    .WithExistingResourceGroup(resourceGroupName)
                    .DefineRule("New-SSH-Port")
                        .AllowInbound()
                        .FromAnyAddress()
                        .FromAnyPort()
                        .ToAnyAddress()
                        .ToPort(agentConfig.SshPort)
                        .WithProtocol(SecurityRuleProtocol.Tcp)
                        .WithPriority(900)
                        .WithDescription("New SSH Port")
                        .Attach()
                    .DefineRule("Benchmark-Port")
                        .AllowInbound()
                        .FromAnyAddress()
                        .FromAnyPort()
                        .ToAnyAddress()
                        .ToPort(agentConfig.OtherPort)
                        .WithProtocol(SecurityRuleProtocol.Tcp)
                        .WithPriority(901)
                        .WithDescription("Benchmark Port")
                        .Attach()
                    .DefineRule("Service-Ports")
                        .AllowInbound()
                        .FromAnyAddress()
                        .FromAnyPort()
                        .ToAnyAddress()
                        .ToPortRange(5001, 5003)
                        .WithProtocol(SecurityRuleProtocol.Tcp)
                        .WithPriority(903)
                        .WithDescription("Service Port")
                        .Attach()
                    .DefineRule("Chat-Sample-Ports")
                        .AllowInbound()
                        .FromAnyAddress()
                        .FromAnyPort()
                        .ToAnyAddress()
                        .ToPort(agentConfig.ChatSamplePort)
                        .WithProtocol(SecurityRuleProtocol.Tcp)
                        .WithPriority(904)
                        .WithDescription("Chat Sample Port")
                        .Attach()
                    .CreateAsync();
                nsgTaskList.Add(nsg);
            }
            Util.Log($"Finish creating network security group...");

            var nicTaskList = new List<Task<INetworkInterface>>();
            Util.Log("Creating network interface...");
            for (var i = 0; i < agentConfig.VmCount; i++)
            {
                var nicName = agentConfig.Prefix + Convert.ToString(i) + "NIC";
                Task<INetworkInterface> networkInterface = null;
                if (agentConfig.AcceleratedNetwork)
                {
                    networkInterface = azure.NetworkInterfaces.Define(nicName)
                        .WithRegion(region)
                        .WithExistingResourceGroup(resourceGroupName)
                        .WithExistingPrimaryNetwork(network)
                        .WithSubnet(subNetName)
                        .WithPrimaryPrivateIPAddressDynamic()
                        .WithExistingPrimaryPublicIPAddress(publicIpTaskList[i].Result)
                        .WithExistingNetworkSecurityGroup(nsgTaskList[i].Result)
                        .WithAcceleratedNetworking()
                        .CreateAsync();
                }
                else
                {
                    networkInterface = azure.NetworkInterfaces.Define(nicName)
                        .WithRegion(region)
                        .WithExistingResourceGroup(resourceGroupName)
                        .WithExistingPrimaryNetwork(network)
                        .WithSubnet(subNetName)
                        .WithPrimaryPrivateIPAddressDynamic()
                        .WithExistingPrimaryPublicIPAddress(publicIpTaskList[i].Result)
                        .WithExistingNetworkSecurityGroup(nsgTaskList[i].Result)
                        .CreateAsync();
                }
                nicTaskList.Add(networkInterface);
            }
            Util.Log("Finish creating network interface...");

            for (var i = 0; i < agentConfig.VmCount; i++)
            {
                var vm = azure.VirtualMachines.Define(agentConfig.Prefix + Convert.ToString(i))
                    .WithRegion(region)
                    .WithExistingResourceGroup(resourceGroupName)
                    .WithExistingPrimaryNetworkInterface(nicTaskList[i].Result)
                    .WithLinuxCustomImage(img.Id)
                    .WithRootUsername(agentConfig.Username)
                    .WithSsh(sshPubKey)
                    .WithComputerName(agentConfig.Prefix + Convert.ToString(i))
                    .WithSize(VmSize);
                creatableVirtualMachines.Add(vm);
            }
            Util.Log("Ready to create virtual machine...");
            
            sw.Stop();
            Util.Log($"prepare for creating vms elapsed time: {sw.Elapsed.TotalMinutes} min");

            sw.Restart();
            Util.Log($"Creating vms");
            var virtualMachines = azure.VirtualMachines.Create(creatableVirtualMachines.ToArray());
            Util.Log($"Finish creating vms");

            Util.Log("Check SSH port");
            var portCheckTaskList = new List<Task>();
            for (var i = 0; i < agentConfig.VmCount; i++)
            {
                var publicIPAddress = azure.PublicIPAddresses.GetByResourceGroup(resourceGroupName, agentConfig.Prefix + Convert.ToString(i) + "PubIP");
                portCheckTaskList.Add(Task.Run(() => WaitPortOpen(publicIPAddress.IPAddress, 22222)));
            }
            
            if (Task.WaitAll(portCheckTaskList.ToArray(), TimeSpan.FromSeconds(120)))
            {
                Util.Log("All ports are ready");
            }
            else
            {
                Util.Log("Not all ports are ready");
            }

            sw.Stop();
            Util.Log($"creating vms elapsed time: {sw.Elapsed.TotalMinutes} min");
            if (agentConfig.VMHostFile != null)
            {
                var builder = new StringBuilder();
                for (var i = 0; i < agentConfig.VmCount; i++)
                {
                    if (i != 0)
                    {
                        builder.Append('|');
                    }
                    builder.Append(agentConfig.Prefix).Append(i).Append(".")
                           .Append(region.Name).Append(".cloudapp.azure.com");
                }
                System.IO.File.WriteAllText(agentConfig.VMHostFile, builder.ToString());
            }
            if (agentConfig.BenchClientListFile != null)
            {
                var builder = new StringBuilder();
                for (var i = 0; i < agentConfig.VmCount; i++)
                {
                    if (i != 0)
                    {
                        builder.Append('|');
                    }
                    builder.Append(agentConfig.Prefix).Append(i).Append(".")
                           .Append(region.Name).Append(".cloudapp.azure.com")
                           .Append(':').Append(agentConfig.SshPort).Append(':').Append(agentConfig.Username);
                }
                System.IO.File.WriteAllText(agentConfig.BenchClientListFile, builder.ToString());
            }
        }

        static void CheckVMPorts(string[] args)
        {
            bool invalidOptions = false;
            // parse args
            var agentConfig = new ArgsOption();
            var result = Parser.Default.ParseArguments<ArgsOption>(args)
                .WithParsed(options => agentConfig = options)
                .WithNotParsed(error => {
                    Console.WriteLine($"Fail to parse the options: {error}");
                    invalidOptions = true;
                });
            if (invalidOptions)
            {
                return;
            }

            var sw = new Stopwatch();
            sw.Start();

            // auth file
            Util.Log($"auth file: {agentConfig.AuthFile}");
            var credentials = SdkContext.AzureCredentialsFactory
                .FromFile(agentConfig.AuthFile);

            var azure = Azure
                .Configure()
                .WithLogLevel(HttpLoggingDelegatingHandler.Level.Basic)
                .Authenticate(credentials)
                .WithDefaultSubscription();
            var pubIP = azure.PublicIPAddresses.GetByResourceGroup("honzhanautovm0705", "hzautovm07050PubIP");
            Util.Log($"Public IP: {pubIP.IPAddress}");
            CheckAllPorts(pubIP.IPAddress);
        }

        static void CheckAllPorts(string ipAddr)
        {
            var portCheckTaskList = new List<Task>();
            portCheckTaskList.Add(Task.Run(() => WaitPortOpen(ipAddr, 22222)));
            if (Task.WaitAll(portCheckTaskList.ToArray(), TimeSpan.FromSeconds(120)))
            {
                Util.Log("All ports are ready");
            }
            else
            {
                Util.Log("Not all ports are ready");
            }
        }

        static void WaitPortOpen(string ipAddr, int port)
        {
            using (var cts = new CancellationTokenSource())
            {
                Util.Log($"Check {ipAddr}:{port} open or not");
                cts.CancelAfter(TimeSpan.FromSeconds(120));
                while (!cts.IsCancellationRequested)
                {
                    if (Util.isPortOpen(ipAddr, port))
                    {
                        break;
                    }
                }
            }
        }
    }
}
