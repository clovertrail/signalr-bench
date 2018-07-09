﻿using CommandLine;

namespace VMAccess
{
    class ArgsOption
    {
        [Option('i', "img-resource-group", Required = true, HelpText = "Specify the image resource group")]
        public string ImgResourceGroup { get; set; }

        [Option('n', "img-name", Required = true, HelpText = "Specify the image name")]
        public string ImgName { get; set; }

        [Option('s', "resource-group", Required = true, HelpText = "Specify the target resource group")]
        public string ResourceGroup { get; set; }

        [Option('p', "prefix", Required = true, HelpText = "Specify VM Prefix for vm")]
        public string Prefix { get; set; }

        [Option('S', "vmsize", Required = true, HelpText = "Specify VM Size: Standard_DS1, Standard_DS4_v2, Standard_D4, Standard_F4")]
        public string VmSize { get; set; }

        [Option('u', "username", Default = "honzhan", Required = false, HelpText = "Specify the ssh login username. Default is honzhan")]
        public string Username { get; set; }

        [Option('A', "accelerated-network", Default = false, Required = false, HelpText = "Whether enable accelerated-network or not, default is disabled")]
        public bool AcceleratedNetwork { get; set; }

        [Option('c', "vmcount", Default = 1, Required = false, HelpText = "Specify VM Count, Default is 1")]
        public int VmCount { get; set; }

        [Option('a', "app", Required = true, HelpText = "Specify Auth File")]
        public string AuthFile { get; set; }

        [Option('m', "accelerated-network VM size file", Required = true, HelpText = "Specify valid accelerated networking VM Size File")]
        public string CandidateOfAcceleratedNetVM { get; set; }

        [Option('H', "sshpubkey-file", Required = false, HelpText = "Specify Ssh Pub Key File")]
        public string SshPubKeyFile { get; set; }

        [Option('z', "sshport", Default = 22222, Required = false, HelpText = "Specify Ssh Port, default is 22222")]
        public int SshPort { get; set; }

        [Option('b', "benchmark-port", Default = 7000, Required = false, HelpText = "Specify Benchmark Port, default is 7000")]
        public int OtherPort { get; set; }

        [Option('C', "chat-sample-port", Default = 5050, Required = false, HelpText = "Specify Chat Sample Port, default is 5050")]
        public int ChatSamplePort { get; set; }

        [Option('o', "benchclient-file", Required = false, HelpText = "Specify the file to save 'client_host1:port:user|client_host2:port:user' content")]
        public string BenchClientListFile { get; set; }

        [Option('O', "vm-host-file", Required = false, HelpText = "Specify the file to save 'client_host1|client_host2' content")]
        public string VMHostFile { get; set; }

        [Option('h', "help", Required = false, HelpText = "dotnet run -- -a E:/home/Work/secrets/azureauth.properties -i honzhanperfsea -n hzbenchclientimg -s honzhanautovm0705 -p hzautovm0705 -S Standard_DS1_v2 -H E:/home/PuttyKeys/azure_ssh_pub -c 10 -u honzhan -o benchclient.txt -O vmhost.txt -A true -m accelerated_network_vmsize.txt")]
        public int Help { get; set; }
    }
}