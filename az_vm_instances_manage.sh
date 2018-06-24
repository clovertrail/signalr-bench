. ./utils.sh
. ./az_vm_manage.sh
. ./vm_env.sh

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

restart_single_vm() {
 local index=$1
 local dns=$2
 local name=$3
 az vm restart -g $g_resource_group -n $name --no-wait
}

restart_all_vms() {
 iterate_all_vm_name restart_single_vm
}

add_user_pub_key_for_single_vm() {
 local index=$1
 local dns=$2
 local name=$3

 az vm user update \
  --resource-group $g_resource_group \
  --name $name \
  --username ${g_ssh_user} \
  --ssh-key-value $t_pub_key_file \
  --no-wait
}

add_user_pub_key_for_all_vms() {
 t_pub_key_file=$1
 iterate_all_vm_name add_user_pub_key_for_single_vm
}

verify_ssh_connection_for_single_vm() {
 local index=$1
 local dns=$2
 local name=$3
 local hostname=${name}.${g_location}".cloudapp.azure.com"

 local end=$((SECONDS + 60))
 while [ $SECONDS -lt $end ]
 do
   ssh -i $t_private_key_file -p $g_ssh_port -q -o StrictHostKeyChecking=no -o BatchMode=yes -o ConnectTimeout=5 ${g_ssh_user}@${hostname} exit
   if [ $? -eq 0 ]
   then
     break
   fi
   sleep 1
 done
 echo "Fail to ssh -i $t_private_key_file -p $g_ssh_port -q -o StrictHostKeyChecking=no -o BatchMode=yes -o ConnectTimeout=5 ${g_ssh_user}@${hostname}"
}

# require private key to verify ssh connection
verify_ssh_connection_for_all_vms() {
 t_private_key_file=$1
 echo "" > ~/.ssh/known_hosts # clean the known_hosts to avoid key conflict
 iterate_all_vm_name verify_ssh_connection_for_single_vm
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

create_single_vm_from_img() {
 local index=$1
 local dns=$2
 local name=$3
 create_vm_from_img_no_wait $g_resource_group $name $g_ssh_user $g_ssh_pubkey_file $g_vm_size $g_location $g_myimg_resouce_id 
}

create_all_vms_from_img() {
 create_resource_group $g_resource_group $g_location
 iterate_all_vm_name create_single_vm_from_img 
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
 local hostname=${name}.${g_location}".cloudapp.azure.com"

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
 local pubip=`az vm list-ip-addresses -g $g_resource_group -n $name|jq ".[].virtualMachine.network.publicIpAddresses[0].ipAddress"|tr -d '"'`
 #change_sshd_port $hostname ${g_ssh_user} $g_ansible_scripts_folder
cat << EOF >> $t_host_file
client${index} ansible_host=$pubip ansible_port=22 ansible_user=${g_ssh_user}
EOF
}

change_all_vm_sshd_port() {
 t_host_file=$g_ansible_scripts_folder/autogen_sshd_port_hosts
 echo "[linux]" > $t_host_file
 iterate_all_vm_name change_sshd_port_for_single_vm
 cd $g_ansible_scripts_folder
 ansible-playbook -i $t_host_file change_sshd_port.yaml
 cd - 
}

setup_benchmark_on_single_vm() {
 local index=$1
 local dns=$2
 local name=$3
 local hostname=${dns}.${g_location}".cloudapp.azure.com"
 local pubip=`az vm list-ip-addresses -g $g_resource_group -n $name|jq ".[].virtualMachine.network.publicIpAddresses[0].ipAddress"|tr -d '"'`
 #prepare_bench_client $hostname $g_ssh_user ${g_ssh_port} $g_ansible_scripts_folder
cat << EOF >> $t_host_file
cli${index} ansible_host=$pubip ansible_port=$g_ssh_port ansible_user=${g_ssh_user}
EOF
}

setup_benchmark_on_all_clients() {
 t_host_file=$g_ansible_scripts_folder/autogen_install_bench_cli
 echo "[linux]" > $t_host_file
 iterate_all_vm_name setup_benchmark_on_single_vm

 cd $g_ansible_scripts_folder
 ansible-playbook -i $t_host_file pam_limits.yaml
 ansible-playbook -i $t_host_file install_config_go.yaml
 ansible-playbook -i $t_host_file git_clone_websocket.yaml
 ansible-playbook -i $t_host_file build_websocket.yaml
 cd -
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

 az vm wait -g $g_resource_group -n $name --created --timeout $g_vm_wait_timeout
}

wait_for_all_vm_creation() {
  iterate_all_vm_name wait_for_single_vm_creation
}

add_pubkey_on_all_vms() {
  user_pubkey_update_all_vms $g_ssh_user pubkey/id_rsa.pub $g_resource_group
}

delete_resource_group() {
  az group delete --name $g_resource_group -y
}


create_vms_instance_from_img() {
  create_all_vms_from_img

  wait_for_all_vm_creation

  enable_nsg_ports_for_all

  sleep 120

  verify_ssh_connection_for_all_vms $g_ssh_private_file
  #add_user_pub_key_for_all_vms pubkey/benchserver_id_rsa.pub
  #add_user_pub_key_for_all_vms pubkey/singlecpu_id_rsa.pub
}
