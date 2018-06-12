#!/bin/bash

g_resource_group="honzhanclients"
g_location="westus2"
g_ssh_user="honzhan"
g_ssh_port=22222
g_ssh_pubkey_file=pubkey/azure_ssh_pub
g_vm_size="Standard_DS1_v2" #"Standard_B1ms"
g_total_vms=5
g_dns_prefix="benchcli"
g_img="UbuntuLTS"
g_ansible_scripts_folder=$HOME/signalr-bench/ansible
