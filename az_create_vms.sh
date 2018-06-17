#!/bin/bash
. ./az_vm_instances_manage.sh

create_vms_instance() {
  create_all_vms

  wait_for_all_vm_creation

  enable_nsg_ports_for_all

  change_all_vm_sshd_port

  add_user_pub_key_for_all_vms pubkey/benchserver_id_rsa.pub
  add_user_pub_key_for_all_vms pubkey/singlecpu_id_rsa.pub
  #user_pubkey_update_all_vms $g_ssh_user pubkey/benchserver_id_rsa.pub $g_resource_group
  #user_pubkey_update_all_vms $g_ssh_user pubkey/singlecpu_id_rsa.pub $g_resource_group

  setup_benchmark_on_all_clients

  gen_ssh_access_endpoint_for_signalr_bench

  list_all_pubip
}
echo "---------------------------"
date

az_login_signalr_dev_sub

create_vms_instance

echo "---------------------------"
date
