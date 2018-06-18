#!/bin/bash

g_resource_group="honzhanclients2" #"honzhanclients"
g_location="westus2"
g_ssh_user="honzhan"
g_ssh_port=22222
g_ssh_pubkey_file=pubkey/id_rsa.pub
g_vm_size="Standard_DS1_v2" #"Standard_B1ms"
g_total_vms=50
g_dns_prefix="benchc" #"benchcli" please change it
g_img="UbuntuLTS"
g_ansible_scripts_folder=$HOME/signalr-bench/ansible
