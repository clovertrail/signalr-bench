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
using System.IO;
using System.Text;
using System.Threading;
using System.Threading.Tasks;

namespace VMAccess
{
    class Program
    {
        static void Main(string[] args)
        {
            CheckInputArgs(args);
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

        static INetwork CreateVirtualNetworkWithRetry(IAzure azure,
            string subNetName, string resourceGroupName,
            string virtualNetName, Region region)
        {
            var maxRetry = 3;
            var i = 0;
            while (i < maxRetry)
            {
                try
                {
                    var network = azure.Networks.Define(virtualNetName)
                        .WithRegion(region)
                        .WithExistingResourceGroup(resourceGroupName)
                        .WithAddressSpace("10.0.0.0/16")
                        .WithSubnet(subNetName, "10.0.0.0/24")
                        .Create();
                    return network;
                }
                catch (Exception)
                {
                    //var net = azure.Networks.GetByResourceGroup(resourceGroupName, virtualNetName);
                    if (i + 1 < maxRetry)
                    {
                        Util.Log($"Fail to create virtual network and will retry");
                    }
                    else
                    {
                        Util.Log($"Fail to create virtual network and retry has reached max limit, will return with failure");
                    }
                }
                i++;
            }
            return null;
        }

        static List<Task<IPublicIPAddress>> CreatePublicIPAddrList(IAzure azure,
            int count, string prefix, string resourceGroupName, Region region)
        {
            var publicIpTaskList = new List<Task<IPublicIPAddress>>();
            var maxTry = 3;
            var j = 0;
            while (j < maxTry)
            {
                try
                {
                    for (var i = 0; i < count; i++)
                    {
                        // create public ip
                        var publicIPAddress = azure.PublicIPAddresses.Define(prefix + Convert.ToString(i) + "PubIP")
                            .WithRegion(region)
                            .WithExistingResourceGroup(resourceGroupName)
                            .WithLeafDomainLabel(prefix + Convert.ToString(i))
                            .WithDynamicIP()
                            .CreateAsync();
                        publicIpTaskList.Add(publicIPAddress);
                    }
                    Task.WaitAll(publicIpTaskList.ToArray());
                    return publicIpTaskList;
                }
                catch (Exception)
                {
                    var allPubIPs = azure.PublicIPAddresses.ListByResourceGroupAsync(resourceGroupName);
                    allPubIPs.Wait();
                    var ids = new List<string>();
                    var enumerator = allPubIPs.Result.GetEnumerator();
                    while (enumerator.MoveNext())
                    {
                        ids.Add(enumerator.Current.Id);
                    }
                    azure.PublicIPAddresses.DeleteByIdsAsync(ids).Wait();
                    if (j + 1 < maxTry)
                    {
                        Util.Log($"Fail to create public IP and will retry");
                    }
                    else
                    {
                        Util.Log($"Fail to create public IP and retry has reached max limit, will return with failure");
                    }
                }
                j++;
            }
            return null;
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
            /*
            var network = azure.Networks.Define(agentConfig.Prefix + "VNet")
                .WithRegion(region)
                .WithExistingResourceGroup(resourceGroupName)
                .WithAddressSpace("10.0.0.0/16")
                .WithSubnet(subNetName, "10.0.0.0/24")
                .Create();
            */
            var network = CreateVirtualNetworkWithRetry(azure, subNetName, resourceGroupName, agentConfig.Prefix + "VNet", region);
            if (network == null)
            {
                throw new Exception("Fail to create virtual network");
            }
            // Prepare a batch of Creatable Virtual Machines definitions
            var creatableVirtualMachines = new List<ICreatable<IVirtualMachine>>();

            // create vms
            Util.Log("Creating public IP address...");
            var publicIpTaskList = CreatePublicIPAddrList(azure, agentConfig.VmCount, agentConfig.Prefix, resourceGroupName, region);
            if (publicIpTaskList == null)
            {
                throw new Exception("Fail to create Public IP Address");
            }
            Util.Log("Finish creating public IP address...");

            Util.Log($"Creating network security group...");
            var nsg = azure.NetworkSecurityGroups.Define(agentConfig.Prefix + "NSG")
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
                    .Create();
            Util.Log($"Finish creating network security group...");

            var nicTaskList = new List<Task<INetworkInterface>>();
            Util.Log("Creating network interface...");
            var allowAcceleratedNet = false;
            if (agentConfig.CandidateOfAcceleratedNetVM != null)
            {
                allowAcceleratedNet = CheckValidVMForAcceleratedNet(agentConfig.CandidateOfAcceleratedNetVM, agentConfig.VmSize);
            }
            for (var i = 0; i < agentConfig.VmCount; i++)
            {
                var nicName = agentConfig.Prefix + Convert.ToString(i) + "NIC";
                Task<INetworkInterface> networkInterface = null;
                if (allowAcceleratedNet && agentConfig.AcceleratedNetwork)
                {
                    networkInterface = azure.NetworkInterfaces.Define(nicName)
                        .WithRegion(region)
                        .WithExistingResourceGroup(resourceGroupName)
                        .WithExistingPrimaryNetwork(network)
                        .WithSubnet(subNetName)
                        .WithPrimaryPrivateIPAddressDynamic()
                        .WithExistingPrimaryPublicIPAddress(publicIpTaskList[i].Result)
                        .WithExistingNetworkSecurityGroup(nsg)
                        .WithAcceleratedNetworking()
                        .CreateAsync();
                    Util.Log("Accelerated Network is enabled!");
                }
                else
                {
                    Util.Log("Accelerated Network is disabled!");
                    networkInterface = azure.NetworkInterfaces.Define(nicName)
                        .WithRegion(region)
                        .WithExistingResourceGroup(resourceGroupName)
                        .WithExistingPrimaryNetwork(network)
                        .WithSubnet(subNetName)
                        .WithPrimaryPrivateIPAddressDynamic()
                        .WithExistingPrimaryPublicIPAddress(publicIpTaskList[i].Result)
                        .WithExistingNetworkSecurityGroup(nsg)
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

        static bool CheckValidVMForAcceleratedNet(string accelVMSizeFile, string vmSize)
        {
            bool found = false;
            IEnumerable<string> lines = File.ReadLines(accelVMSizeFile);
            var enumerator = lines.GetEnumerator();
            while (enumerator.MoveNext())
            {
                if (enumerator.Current.Equals(vmSize))
                {
                    found = true;
                    break;
                }
            }
            return found;
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
