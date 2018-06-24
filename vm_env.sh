#!/bin/bash

g_resource_group="honzhantbench"
g_location="westus2"
g_ssh_user="honzhan"
g_ssh_port=22222
g_ssh_pubkey_file=$HOME/.ssh/id_rsa.pub
g_ssh_private_file=$HOME/.ssh/id_rsa
g_vm_size="Standard_DS1_v2" #"Standard_B1ms"
g_total_vms=5
g_dns_prefix="testbench"
g_img="UbuntuLTS"
g_myimg_name="hzbenchserverimg"
g_myimg_rsg_name="honzhansignalrbench"
g_myimg_resouce_id="/subscriptions/685ba005-af8d-4b04-8f16-a7bf38b2eb5a/resourceGroups/honzhansignalrbench/providers/Microsoft.Compute/images/hzbenchserverimg"
g_ansible_scripts_folder=$HOME/signalr-bench/ansible
