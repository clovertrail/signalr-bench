#!/bin/bash
. ./az_vm_instances_manage.sh

create_vms_instance_from_img() {
  create_all_vms_from_img

  wait_for_all_vm_creation

  enable_nsg_ports_for_all

  sleep 120

  verify_ssh_connection_for_all_vms $g_ssh_private_file
  #add_user_pub_key_for_all_vms pubkey/benchserver_id_rsa.pub
  #add_user_pub_key_for_all_vms pubkey/singlecpu_id_rsa.pub

  gen_ssh_access_endpoint_for_signalr_bench

  list_all_pubip
}
echo "---------------------------"
date

#az_login_signalr_dev_sub
az_login_java_test_7ttl

g_location=get_vm_img_location $g_myimg_rsg_name $g_myimg_name #VM must locate the same region as image

create_vms_instance_from_img

echo "---------------------------"
date
