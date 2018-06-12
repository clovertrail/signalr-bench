. ./utils.sh
. ./az_vm_manage.sh
. ./vm_env.sh

az_login_jenkins_sub

check_exisiting() {
  local grp=$1
  local is_existing=$(az group exists --name $grp 2>&1)
  echo $is_existing
}

iterate_all_vm_name() {
 local callback=$1
  
 local i=0
 while [ $i -lt $g_total_vms ]
 do
  local dns=${g_dns_prefix}${i}
  local name=${g_ssh_user}${dns}
  $callback $i $dns $name
  i=$(($i + 1))
 done
}

create_single_vm() {
 local index=$1
 local dns=$2
 local name=$3
 create_vm $name $g_img $g_location $g_ssh_user $g_ssh_pubkey_file $g_vm_size $g_resource_group $dns
}

create_all_vms() {
 create_resource_group $g_resource_group $g_location
 iterate_all_vm_name create_single_vm
}

add_nsg_ports_for_single_vm() {
 local index=$1
 local dns=$2
 local name=$3
 add_nsg_ports_for_all $name $g_resource_group $g_ssh_port
}

enable_nsg_ports_for_all() {
 iterate_all_vm_name add_nsg_ports_for_single_vm
}

gen_ssh_access_endpoint_for_single_vm() {
 local index=$1
 local dns=$2
 local name=$3
 local hostname=${dns}.${g_location}".cloudapp.azure.com"

 if [ $index -ne 0 ]
 then
   echo -n "|"
 fi
 if [ `expr $index + 1` -eq $g_total_vms ]
 then
   echo "${hostname}:${g_ssh_port}:${g_ssh_user}"
 else
   echo -n "${hostname}:${g_ssh_port}:${g_ssh_user}"
 fi
}

gen_ssh_access_endpoint_for_signalr_bench() {
 iterate_all_vm_name gen_ssh_access_endpoint_for_single_vm
}

change_sshd_port_for_single_vm() {
 local index=$1
 local dns=$2
 local name=$3
 local hostname=${dns}.${g_location}".cloudapp.azure.com"
 change_sshd_port $hostname ${g_ssh_user} $g_ansible_scripts_folder
}

change_all_vm_sshd_port() {
 iterate_all_vm_name change_sshd_port_for_single_vm
}

setup_benchmark_on_single_vm() {
 local index=$1
 local dns=$2
 local name=$3
 local hostname=${dns}.${g_location}".cloudapp.azure.com"
 prepare_bench_client $hostname $g_ssh_user ${g_ssh_port} $g_ansible_scripts_folder
}

setup_benchmark_on_all_clients() {
 iterate_all_vm_name setup_benchmark_on_single_vm
}

list_pubip_for_single_vm() {
 local index=$1
 local dns=$2
 local name=$3
 list_vm_public_ip $name $g_resource_group
}

list_all_pubip() {
 iterate_all_vm_name list_pubip_for_single_vm
}

wait_for_single_vm_creation() {
 local index=$1
 local dns=$2
 local name=$3

 az vm wait -g $g_resource_group -n $name --created
}

wait_for_all_vm_creation() {
  iterate_all_vm_name wait_for_single_vm_creation
}

create_vms_instance() {
  create_all_vms

  wait_for_all_vm_creation

  enable_nsg_ports_for_all

  change_all_vm_sshd_port

  user_pubkey_update_all_vms $g_ssh_user pubkey/id_rsa.pub $g_resource_group
  user_pubkey_update_all_vms $g_ssh_user pubkey/benchserver_id_rsa.pub $g_resource_group
  user_pubkey_update_all_vms $g_ssh_user pubkey/singlecpu_id_rsa.pub $g_resource_group

  setup_benchmark_on_all_clients

  gen_ssh_access_endpoint_for_signalr_bench

  list_all_pubip
}

add_pubkey_on_all_vms() {
  user_pubkey_update_all_vms $g_ssh_user pubkey/id_rsa.pub $g_resource_group
}

delete_resource_group() {
  az group delete --name $g_resource_group -y
}

echo "---------------------------"
date

#create_vms_instance
#add_pubkey_on_all_vms
#list_all_pubip
#setup_benchmark_on_all_clients
#change_all_vm_sshd_port
 setup_benchmark_on_all_clients
 gen_ssh_access_endpoint_for_signalr_bench
#delete_resource_group

echo "---------------------------"
date

