using CommandLine;
using Microsoft.Azure.Management.Compute.Fluent;
using Microsoft.Azure.Management.Compute.Fluent.Models;
using Microsoft.Azure.Management.Fluent;
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
        static async Task Main(string[] args)
        {
            await CreateVM(args);
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
            if (agentConfig.SshPubKeyFile != null)
            {
                var sshPubKey = System.IO.File.ReadAllText(agentConfig.SshPubKeyFile);
                Util.Log($"SSH public key: {sshPubKey}");
            }
            Util.Log($"Accelerated Network: {agentConfig.AcceleratedNetwork}");
        }

        static async Task CreateVM(string[] args)
        {
            bool invalidOptions = false;
            // parse args
            var agentConfig = new ArgsOption();
            var result = Parser.Default.ParseArguments<ArgsOption>(args)
                .WithParsed(options => agentConfig = options)
                .WithNotParsed(error => {
                    Util.Log($"Fail to parse the options: {error}");
                    invalidOptions = true;
                });
            if (invalidOptions)
            {
                Util.Log("Invalid options");
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
            var img = await Util.GetVMImageWithRetry(azure,
                                                     agentConfig.ImgResourceGroup,
                                                     agentConfig.ImgName,
                                                     agentConfig.MaxRetry);
            if (img == null)
            {
                throw new Exception("Fail to get custom image");
            }
            Util.Log($"Customized image id: {img.Id}");

            var region = img.Region;
            Util.Log($"target region: {region.Name}");

            var VmSize = VirtualMachineSizeTypes.Parse(agentConfig.VmSize);
            Util.Log($"VM size: {VmSize}");

            string sshPubKey = null;
            if (agentConfig.SshPubKeyFile == null && agentConfig.VmType == 1)
            {
                Util.Log("SSH public key is not set for Linux VM");
                throw new Exception("SSH public key is not specified!");
            }
            else if (agentConfig.SshPubKeyFile != null && agentConfig.VmType == 1)
            {
                sshPubKey = File.ReadAllText(agentConfig.SshPubKeyFile);
                Util.Log($"SSH public key: {sshPubKey}");
                Util.Log($"Accelerated Network: {agentConfig.AcceleratedNetwork}");
            }

            if (agentConfig.VmType == 2 && agentConfig.Password == null)
            {
                Util.Log($"You must specify password for windows VM by -p XXXX");
                return;
            }
            var resourceGroupName = agentConfig.ResourceGroup;
            if (!azure.ResourceGroups.Contain(resourceGroupName))
            {
                await azure.ResourceGroups.Define(resourceGroupName).WithRegion(region).CreateAsync();
            }

            // create virtual net
            Util.Log("Creating virtual network...");
            var subNetName = agentConfig.Prefix + "Subnet";
            var network = await Util.CreateVirtualNetworkWithRetry(azure,
                                                                   subNetName,
                                                                   resourceGroupName,
                                                                   agentConfig.Prefix + "VNet",
                                                                   region,
                                                                   agentConfig.MaxRetry);
            if (network == null)
            {
                throw new Exception("Fail to create virtual network");
            }
            Util.Log("Finish creating virtual network");
            // Prepare a batch of Creatable Virtual Machines definitions
            var creatableVirtualMachines = new List<ICreatable<IVirtualMachine>>();

            // create vms
            Util.Log("Creating public IP address...");
            var publicIpTaskList = await Util.CreatePublicIPAddrListWithRetry(azure,
                                                                              agentConfig.VmCount,
                                                                              agentConfig.Prefix,
                                                                              resourceGroupName,
                                                                              region,
                                                                              agentConfig.MaxRetry);
            if (publicIpTaskList == null)
            {
                throw new Exception("Fail to create Public IP Address");
            }
            Util.Log("Finish creating public IP address...");

            Util.Log($"Creating network security group...");
            var nsg = await Util.CreateNetworkSecurityGroupWithRetry(azure,
                                                                     resourceGroupName,
                                                                     agentConfig.Prefix + "NSG",
                                                                     agentConfig,
                                                                     region);
            if (nsg == null)
            {
                throw new Exception("Fail to create network security group");
            }
            Util.Log($"Finish creating network security group...");

            Util.Log("Creating network interface...");
            var nicTaskList = await Util.CreateNICWithRetry(azure,
                                                            resourceGroupName,
                                                            agentConfig,
                                                            network,
                                                            publicIpTaskList,
                                                            subNetName,
                                                            nsg,
                                                            region);
            if (nicTaskList == null)
            {
                throw new Exception("Fail to create NIC task list");
            }
            Util.Log("Finish creating network interface...");

            if (agentConfig.VmType == 1)
            {
                for (var i = 0; i < agentConfig.VmCount; i++)
                {
                    var vmName = agentConfig.VmCount == 1 ? agentConfig.Prefix : agentConfig.Prefix + Convert.ToString(i);
                    var vm = azure.VirtualMachines.Define(vmName)
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
            }
            else if (agentConfig.VmType == 2)
            {
                for (var i = 0; i < agentConfig.VmCount; i++)
                {
                    var vmName = agentConfig.VmCount == 1 ? agentConfig.Prefix : agentConfig.Prefix + Convert.ToString(i);
                    var vm = azure.VirtualMachines.Define(vmName)
                        .WithRegion(region)
                        .WithExistingResourceGroup(resourceGroupName)
                        .WithExistingPrimaryNetworkInterface(nicTaskList[i].Result)
                        .WithWindowsCustomImage(img.Id)
                        .WithAdminUsername(agentConfig.Username)
                        .WithAdminPassword(agentConfig.Password)
                        .WithComputerName(agentConfig.Prefix + Convert.ToString(i))
                        .WithSize(VmSize);
                    creatableVirtualMachines.Add(vm);
                }
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
                var publicIPAddress = azure.PublicIPAddresses
                                           .GetByResourceGroup(resourceGroupName,
                                                               agentConfig.Prefix + Convert.ToString(i) + "PubIP");
                portCheckTaskList.Add(Task.Run(async () => await WaitPortOpen(publicIPAddress.IPAddress, agentConfig.SshPort)));
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
            Util.Log($"creating vms elapsed time: {sw.Elapsed.TotalMinutes} minutes");
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
                File.WriteAllText(agentConfig.VMHostFile, builder.ToString());
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
                File.WriteAllText(agentConfig.BenchClientListFile, builder.ToString());
            }
        }

        static async Task WaitPortOpen(string ipAddr, int port)
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
                    await Task.Delay(TimeSpan.FromSeconds(1));
                }
            }
        }
    }
}
