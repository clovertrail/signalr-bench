#!/bin/bash
## Required parameters:
# ResourceGroup, VMSizeList, VMHostPrefixList,
# EchoConnectionNumberList, EchoSendNumberList, EchoConcurrentConnectNumberList, EchoConnectionStepList
# BroadcastConnectionNumberList, BroadcastSendNumberList, BroadcastConcurrentConnectNumberList, BroadcastConcurrentStepList
# RedisConnectString, Duration, MaxTryList, GitBranch
. ./utils.sh
. ./func_env.sh
. ./build_launch_signalr_service.sh

echo "-------Your Jenkins Inputs------"
echo "[EchoConnectionNumberList]: $EchoConnectionNumberList"
echo "[EchoSendNumberList]: $EchoSendNumberList"
echo "[EchoConcurrentConnectNumberList]: $EchoConcurrentConnectNumberList"
echo "[EchoConnectionStepList]: $EchoConnectionStepList"
echo "[BroadcastConnectionNumberList]: $BroadcastConnectionNumberList"
echo "[BroadcastSendNumberList]: $BroadcastSendNumberList"
echo "[BroadcastConcurrentConnectNumberList]: $BroadcastConcurrentConnectNumberList"
echo "[BroadcastConnectionStepList]: $BroadcastConnectionStepList"
echo "[Duration]: $Duration"
echo "[MaxTryList]: $MaxTryList"
echo "[VMSizeList]: $VMSizeList"
echo "[VMHostPrefixList]: $VMHostPrefixList"
echo "[GitBranch]: $GitBranch"
echo "[RedisConnectString]: $RedisConnectString"

g_service_host=$ServiceHost
g_echo_connection_number=$EchoConnectionNumber
g_echo_send_number=$EchoSendNumber
g_echo_concurrent_connection_number=$EchoConcurrentConnectNumber
g_echo_connection_step=$EchoConnectionStep
g_broadcast_connection_number=$BroadcastConnectionNumber
g_broadcast_send_number=$BroadcastSendNumber
g_broadcast_concurrent_connection_number=$BroadcastConcurrentConnectNumber
g_broadcast_connection_step=$BroadcastConnectionStep
g_duration=$Duration

function multiple_try_run() {
  local service_host=$g_service_host
  local duration=$g_duration
  local max_try=$g_max_try
  local echo_connection_number=$g_echo_connection_number
  local echo_concurrent_connection_number=$g_echo_concurrent_connection_number
  local echo_send_number=$g_echo_send_number
  local echo_step=$g_echo_connection_step
  local broadcast_step=$g_broadcast_connection_step
  local broadcast_connection_number=$g_broadcast_connection_number
  local broadcast_concurrent_connection_number=$g_broadcast_concurrent_connection_number
  local broadcast_send_number=$g_broadcast_send_number

  local i=0

  local connection_string
  connection_string="Endpoint=http://$service_host;AccessKey=ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"

  local tag
  while [ $i -lt $max_try ]
  do
    tag="${g_vmsize}-${echoconnection_number}-${broadcastconnection_number}"
cat << EOF > jenkins_env.sh
sigbench_run_duration=$duration
echoconnection_number=$echo_connection_number
echoconnection_concurrent=$echo_concurrent_connection_number
echosend_number=$echo_send_number
broadcastconnection_number=$broadcast_connection_number
broadcastconnection_concurrent=$broadcast_concurrent_connection_number
broadcastsend_number=$broadcast_send_number
connection_concurrent=$echo_concurrent_connection_number
connection_number=$echo_connection_number
send_number=$echo_send_number
bench_type_list="${tag}"
use_https=0
connection_string="$connection_string"
EOF
    mkdir $result_root/$tag

    local service_launch_log=$result_root/$tag/service_launch.log
    launch_service $servicebin_dir $service_host $bench_service_user $bench_service_pub_port $service_launch_log

    local launch_status=$(check_service_launch_status $service_launch_log)
    if [ $launch_status -ne 0 ]
    then
      echo "Launch failed!"
      return
    else 
      sh jenkins-run-websocket.sh
    fi
    if [ -e $result_root/$error_mark_file ]
    then
       echo "!!!Stop trying since error occurs"
       return
    fi
    echo_connection_number=$((echo_connection_number + $echo_step))
    echo_send_number=$((echo_send_number + $echo_step))
    broadcast_connection_number=$((broadcast_connection_number + $broadcast_step))
    broadcast_send_number=$((broadcast_send_number + $broadcast_step))
    broadcast_concurrent_number=$broadcast_connection_number
    i=`expr $i + 1`
  done
}

git_clone_and_build() {
  local servicebin_dir=$1
  local git_branch=$2
  if [ -e $servicebin_dir ]
  then
    rm -fr $servicebin_dir
  fi
  mkdir $servicebin_dir

  local src_root_dir=/tmp/ASRS-`date +%Y%m%d%H%M%S`
  local service_launch_log=$result_root/service_launch.log
  local cur_dir=`pwd`
  local commit_hash_file="$cur_dir"/$result_root/commit_hash.txt

  git_clone $src_root_dir $git_branch

  build_signalr_service $src_root_dir "$cur_dir"/$servicebin_dir "$commit_hash_file"

  local status=$(check_build_status $servicebin_dir)
  if [ $status != 0 ]
  then
    echo 1
  else
    echo 0
  fi
}

create_target_single_service_vm() {
. ./az_vm_instances_manage.sh
  local rsg=$1
  local name_prefix=$2
  local vm_size=$3

  az_login_signalr_dev_sub
  g_create_vms_instance_from_img "hzbenchclientimg" \
                               "honzhanperfsea" \
                               $rsg \
                               $name_prefix \
                               "honzhan" \
                               22222 \
                               $vm_size \
                               1
  exit_if_fail_to_ssh_all_vms
}

run_all() {
 local output_dir=ASRSBin
 local git_build=$(git_clone_and_build $output_dir $GitBranch)
 if [ $git_build != 0 ]
 then
   echo "Fail to build SignalR Service!!!"
 fi

 local vm_size vm_host_prefix
 local len=$(array_len "$VMSizeList" "|")
 local i=1
 while [ $i -le $len ]
 do
   vm_size=$(array_get $VMSizeList $i "|")
   vm_host_prefix=$(array_get $VMHostPrefixList $i "|")
   g_max_try=$(array_get $MaxTryList $i "|")
   ## create VM
   create_target_single_service_vm $ResourceGroup $vm_host_prefix $vm_size
   ServiceHost=$(g_get_vm_hostname 0)
   ## Configure Service
   local uuid=`cat /proc/sys/kernel/random/uuid`
   g_appsetting_file="$result_root/appsetting_tmpl.json"
   if [ "$RedisConnectString" != "" ]
   then
     sed -e "s/RedisConnectString/$RedisConnectString/g;s/dev/$uuid/g" servicetmpl/appsettings_redis.json > $g_appsetting_file
   else
     g_appsetting_file="servicetmpl/appsettings.json"
   fi
   replace_appsettings $output_dir $ServiceHost $g_appsetting_tmpl
   zip_signalr_service $output_dir
   ## generate configuration
   local echo_connection_number=$(array_get $EchoConnectionNumberList $i "|")
   local echo_send_number=$(array_get $EchoSendNumberList $i "|")
   local echo_concurrent_number=$(array_get $EchoConcurrentConnectNumberList $i "|")
   local echo_step=$(array_get $EchoStepList $i "|")
   local broadcast_connection_number=$(array_get $BroadcastConnectionNumberList $i "|")
   local broadcast_send_number=$(array_get $BroadcastSendNumberList $i "|")
   local broadcast_concurrent_number=$(array_get $BroadcastConcurrentConnectNumberList $i "|")
   local broadcast_step=$(array_get $BroadcastStepList $i "|")

   g_service_host=$ServiceHost
   g_echo_connection_number=$echo_connection_number
   g_echo_send_number=$echo_send_number
   g_echo_concurrent_connection_number=$echo_concurrent_number
   g_echo_connection_step=$echo_step
   g_broadcast_connection_number=$broadcast_connection_number
   g_broadcast_send_number=$broadcast_send_number
   g_broadcast_concurrent_connection_number=$broadcast_concurrent_number
   g_broadcast_connection_step=$broadcast_step
   g_duration=$Duration
   g_vmsize=$vm_size
   multiple_try_run
   i=$(($i + 1))
 done
}

create_root_folder

run_all

gen_final_report
