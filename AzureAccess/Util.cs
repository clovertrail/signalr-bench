using Microsoft.Azure.Management.Compute.Fluent;
using Microsoft.Azure.Management.Fluent;
using Microsoft.Azure.Management.Network.Fluent;
using Microsoft.Azure.Management.Network.Fluent.Models;
using Microsoft.Azure.Management.ResourceManager.Fluent.Core;
using System;
using System.Collections.Generic;
using System.IO;
using System.Net;
using System.Net.Sockets;
using System.Threading.Tasks;

namespace VMAccess
{
    public class Util
    {
        private static string IPRange = "167.220.148.0/23,131.107.147.0/24,131.107.159.0/24,131.107.160.0/24,131.107.174.0/24,167.220.24.0/24,167.220.26.0/24,167.220.238.0/27,167.220.238.128/27,167.220.238.192/27,167.220.238.64/27,167.220.232.0/23,167.220.255.0/25,167.220.242.0/27,167.220.242.128/27,167.220.242.192/27,167.220.242.64/27,94.245.87.0/24,167.220.196.0/23,194.69.104.0/25,191.234.97.0/26,167.220.0.0/23,167.220.2.0/24,207.68.190.32/27,13.106.78.32/27,10.254.32.0/20,10.97.136.0/22,13.106.174.32/27,13.106.4.96/27,168.61.37.236";
        private static string SubnetIPSpace = "10.220.0.0/24";

        public static void Log(string message)
        {
            var time = DateTime.Now.ToString("hh:mm:ss.fff");
            Console.WriteLine($"[{time}] {message}");
        }

        public static bool isPortOpen(string ip, int port)
        {
            var ipAddr = IPAddress.Parse(ip);
            var endPoint = new IPEndPoint(ipAddr, port);
            try
            {
                var tcp = new TcpClient();
                tcp.Connect(endPoint);
                return true;
            }
            catch (Exception e)
            {
                Log($"Fail to connect to {ip}:{port} for " + e);
                return false;
            }
        }

        public static async Task<IVirtualMachineCustomImage> GetVMImageWithRetry(IAzure azure, string resourceGroupName, string imageName, int maxRetry = 3)
        {
            var i = 0;
            IVirtualMachineCustomImage img = null;
            while (i < maxRetry)
            {
                try
                {
                    img = await azure.VirtualMachineCustomImages.GetByResourceGroupAsync(resourceGroupName, imageName);
                }
                catch (Exception e)
                {
                    Util.Log(e.ToString());
                    if (i + 1 < maxRetry)
                    {
                        Util.Log($"Fail to get VM image for {e.Message} and will retry");
                    }
                    else
                    {
                        Util.Log($"Fail to get VM image for {e.Message} and retry has reached max limit, will return with failure");
                    }
                }
                i++;
            }
            return img;
        }

        public static async Task<INetworkSecurityGroup> CreateNetworkSecurityGroupWithRetry(IAzure azure,
            string resourceGroupName, string name, ArgsOption agentConfig, Region region)
        {
            var azureRegionIP = IPRange;
            var allowedIpRange = azureRegionIP.Split(',');
            INetworkSecurityGroup rtn = null;
            var i = 0;
            var maxRetry = agentConfig.MaxRetry;
            while (i < maxRetry)
            {
                try
                {
                    rtn = await azure.NetworkSecurityGroups.Define(agentConfig.Prefix + "NSG")
                    .WithRegion(region)
                    .WithExistingResourceGroup(resourceGroupName)
                    .DefineRule("New-SSH-Port")
                        .AllowInbound()
                        .FromAddresses(allowedIpRange)
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
                    .DefineRule("RDP-Port")
                        .AllowInbound()
                        .FromAddresses(allowedIpRange)
                        .FromAnyPort()
                        .ToAnyAddress()
                        .ToPort(agentConfig.RDPPort)
                        .WithProtocol(SecurityRuleProtocol.Tcp)
                        .WithPriority(905)
                        .WithDescription("Windows RDP Port")
                        .Attach()
                    .DefineRule("Jenkins-Nginx")
                        .AllowInbound()
                        .FromAddresses(allowedIpRange)
                        .FromAnyPort()
                        .ToAnyAddress()
                        .ToPortRanges(new string[] { "8080", "8181", "8000" })
                        .WithProtocol(SecurityRuleProtocol.Tcp)
                        .WithPriority(906)
                        .WithDescription("Jenkins and Nginx ports")
                        .Attach()
                    .CreateAsync();
                }
                catch (Exception e)
                {
                    Util.Log(e.ToString());
                    if (i + 1 < maxRetry)
                    {
                        Util.Log($"Fail to create security network group for {e.Message} and will retry");
                    }
                    else
                    {
                        Util.Log($"Fail to create security network group for {e.Message} and retry has reached max limit, will return with failure");
                    }
                }
                i++;
            }
            return rtn;
        }

        public static async Task<INetwork> GetVirtualNetworkAsync(
            IAzure azure,
            string resourceGroupName,
            string virtualNetName,
            int maxRetry = 3)
        {
            var i = 0;
            while (i < maxRetry)
            {
                try
                {
                    return await azure.Networks.GetByResourceGroupAsync(resourceGroupName, virtualNetName);
                }
                catch (Exception e)
                {
                    if (i + 1 < maxRetry)
                    {
                        Util.Log($"Fail to create virtual network for {e} and will retry");
                    }
                }
                i++;
            }
            return null;
        }

        public static async Task<INetwork> CreateVirtualNetworkWithRetry(IAzure azure,
            string subNetName, string resourceGroupName,
            string virtualNetName, Region region, int maxRetry = 3)
        {
            var i = 0;
            while (i < maxRetry)
            {
                try
                {
                    var network = await azure.Networks.Define(virtualNetName)
                        .WithRegion(region)
                        .WithExistingResourceGroup(resourceGroupName)
                        .WithAddressSpace(SubnetIPSpace)
                        .WithSubnet(subNetName, SubnetIPSpace)
                        .CreateAsync();
                    return network;
                }
                catch (Exception e)
                {
                    Util.Log(e.ToString());
                    if (i + 1 < maxRetry)
                    {
                        Util.Log($"Fail to create virtual network for {e.Message} and will retry");
                    }
                    else
                    {
                        Util.Log($"Fail to create virtual network for {e.Message} and retry has reached max limit, will return with failure");
                    }
                }
                i++;
            }
            return null;
        }

        public static async Task<List<Task<IPublicIPAddress>>> CreatePublicIPAddrListWithRetry(IAzure azure,
            int count, string prefix, string resourceGroupName, Region region, int maxTry = 3)
        {
            var publicIpTaskList = new List<Task<IPublicIPAddress>>();
            var j = 0;
            var i = 0;
            while (j < maxTry)
            {
                try
                {
                    for (i = 0; i < count; i++)
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
                    await Task.WhenAll(publicIpTaskList.ToArray());
                    return publicIpTaskList;
                }
                catch (Exception e)
                {
                    Util.Log(e.ToString());
                    publicIpTaskList.Clear();

                    var allPubIPs = azure.PublicIPAddresses.ListByResourceGroupAsync(resourceGroupName);
                    await allPubIPs;
                    var ids = new List<string>();
                    var enumerator = allPubIPs.Result.GetEnumerator();
                    while (enumerator.MoveNext())
                    {
                        ids.Add(enumerator.Current.Id);
                    }
                    await azure.PublicIPAddresses.DeleteByIdsAsync(ids);
                    if (j + 1 < maxTry)
                    {
                        Util.Log($"Fail to create public IP for {e.Message} and will retry");
                    }
                    else
                    {
                        Util.Log($"Fail to create public IP for {e.Message} and retry has reached max limit, will return with failure");
                    }
                }
                j++;
            }
            return null;
        }

        public static async Task<List<Task<INetworkInterface>>> CreateNICWithRetry(
            IAzure azure,
            string resourceGroupName,
            ArgsOption agentConfig,
            INetwork network,
            List<Task<IPublicIPAddress>> publicIpTaskList,
            string subNetName,
            INetworkSecurityGroup nsg, Region region)
        {
            var j = 0;
            var i = 0;
            var maxTry = agentConfig.MaxRetry;
            var nicTaskList = new List<Task<INetworkInterface>>();
            while (j < maxTry)
            {
                try
                {
                    var allowAcceleratedNet = false;
                    if (agentConfig.CandidateOfAcceleratedNetVM != null)
                    {
                        allowAcceleratedNet = CheckValidVMForAcceleratedNet(agentConfig.CandidateOfAcceleratedNetVM, agentConfig.VmSize);
                    }
                    for (i = 0; i < agentConfig.VmCount; i++)
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
                    await Task.WhenAll(nicTaskList.ToArray());
                    return nicTaskList;
                }
                catch (Exception e)
                {
                    Util.Log(e.ToString());
                    nicTaskList.Clear();

                    var allNICs = azure.NetworkInterfaces.ListByResourceGroupAsync(resourceGroupName);
                    await allNICs;
                    var ids = new List<string>();
                    var enumerator = allNICs.Result.GetEnumerator();
                    while (enumerator.MoveNext())
                    {
                        ids.Add(enumerator.Current.Id);
                    }
                    await azure.NetworkInterfaces.DeleteByIdsAsync(ids);
                    if (j + 1 < maxTry)
                    {
                        Util.Log($"Fail to create NIC for {e.Message} and will retry");
                    }
                    else
                    {
                        Util.Log($"Fail to create NIC for {e.Message} and retry has reached max limit, will return with failure");
                    }
                }
                j++;
            }
            return null;
        }

        public static bool CheckValidVMForAcceleratedNet(string accelVMSizeFile, string vmSize)
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
    }
}
