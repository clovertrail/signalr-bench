. ./utils.sh
. ./az_vm_manage.sh
. ./vm_env.sh

az_login_signalr_dev_sub

check_exisiting() {
  local grp=$1
  local is_existing=$(az group exists --name $grp 2>&1)
  echo $is_existing
}

create_all_vms() {
 create_resource_group $g_resource_group $g_location
 local i=0
 while [ $i -lt $g_total_vms ]
 do
  local dns=${g_dns_prefix}${i}
  local name=${g_ssh_user}${dns}
  local image=$g_img
  create_vm $name $image $g_location $g_ssh_user $g_ssh_pubkey_file $g_vm_size $g_resource_group $dns
  i=`expr $i + 1`
 done
}

enable_nsg_ports_for_all() {
 local i=0
 while [ $i -lt $g_total_vms ]
 do
  local dns=${g_dns_prefix}${i}
  local name=${g_ssh_user}${dns}

  add_nsg_ports_for_all $name $g_resource_group $g_ssh_port
  i=`expr $i + 1`
 done 
}

gen_client_server_list_for_signalr_bench() {
 local location=$1
 local ssh_user=$2
 local i=0
 while [ $i -lt $g_total_vms ]
 do
  local dns=${g_dns_prefix}${i}.${location}".cloudapp.azure.com"
  if [ $i -ne 0 ]
  then
    echo -n "|"
  fi
  if [ `expr $i + 1` -eq $g_total_vms ]
  then
    echo "${dns}:${g_ssh_port}:${ssh_user}"
  else
    echo -n "${dns}:${g_ssh_port}:${ssh_user}"
  fi
  i=`expr $i + 1`
 done
}

change_sshd_port() {
 local location=$1
 local ssh_user=$2
 local ansible_folder=$3

 local i=0
 while [ $i -lt $g_total_vms ]
 do
  local dns=${g_dns_prefix}${i}.${location}".cloudapp.azure.com"
  change_sshd_port $dns ${g_ssh_user} $ansible_folder
  i=`expr $i + 1`
 done
}

setup_benchmark_on_all_clients() {
 local location=$1
 local ansible_root_dir=$2
 local i=0
 while [ $i -lt $g_total_vms ]
 do
  local dns=${g_dns_prefix}${i}.${location}".cloudapp.azure.com"
  prepare_bench_client $dns $g_ssh_user ${g_ssh_port} $ansible_root_dir
  i=`expr $i + 1`
 done
}

list_all_pubip() {
 local rsg=$1
 local i=0
 while [ $i -lt $g_total_vms ]
 do
   local dns=${g_dns_prefix}${i}
   local name=${g_ssh_user}${dns}
   list_vm_public_ip $name $rsg
   i=`expr $i + 1`
 done
}

echo "---------------------------"
date

#create_all_vms
#enable_nsg_ports_for_all
#change_sshd_port $g_location $g_ssh_user $HOME/signalr-bench/ansible
#user_pubkey_update_all_vms $g_ssh_user ./id_rsa_benchserver.pub $g_resource_group
#list_all_pubip $g_resource_group
#setup_benchmark_on_all_clients $g_location $HOME/signalr-bench/ansible
#gen_client_server_list_for_signalr_bench $g_location $g_ssh_user
#az group delete --name $g_resource_group -y --no-wait

echo "---------------------------"
date

#check_exisiting "honzhandogfood1"
#check_exisiting "honzhandogfood"
