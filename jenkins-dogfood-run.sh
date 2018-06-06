#!/bin/bash
. ./az_signalr_service.sh

. ./func_env.sh
. ./kubectl_utils.sh

# unit 1 ~ 10
g_CPU_requests="1|1|1|2|2|3|3|3|3|4"
g_CPU_limits="1|2|2|2|3|3|4|4|4|4"
g_Memory_limits="1500|1500|1500|1500|1500|2000|2000|2000|3000|3000"

target_grp="honzhanautoperf"
sku="Basic_DS2"
location=$Location

function patch_and_wait() {
  local name=$1
  local rsg=$2
  local index=$3
  local cpu_req=$(array_get $g_CPU_requests $index "|")
  local cpu_limit=$(array_get $g_CPU_limits $index "|")
  local mem_limit=$(array_get $g_Memory_limits $index "|")
  patch ${name} 1 $cpu_limit $cpu_req $mem_limit 12000

  check_signalr_service_dns $rsg $name
}

function run_unit_benchmark() {
  local rsg=$1
  local name=$2
  local sku=$3
  local unit=$4
  local ClientConnectionNumber=`expr $unit \* 1000`

  local signalr_service=$(create_signalr_service $rsg $name $sku $unit)
  if [ "$signalr_service" == "" ]
  then
    echo "Fail to create SignalR Service"
    return
  else
    echo "Create SignalR Service ${signalr_service}"
  fi
  local dns_ready=$(check_signalr_service_dns $rsg $name)
  if [ $dns_ready -eq 1 ]
  then
    echo "SignalR Service DNS is not ready, suppose it is failed!"
    delete_signalr_service $name $rsg
    return
  fi
  local ConnectionString=$(query_connection_string $name $rsg)
  echo "Connection string: '$ConnectionString'"  
  # override jenkins_env.sh
cat << EOF > jenkins_env.sh
sigbench_run_duration=$Duration
connection_concurrent=$ConcurrentConnectionNumber
connection_string="$ConnectionString"
connection_number=$ClientConnectionNumber
send_number=$ClientConnectionNumber
bench_type_list="unit${unit}"
use_https=1
EOF
  # patch it to be 1 replica
  #patch_replicas ${name} 1
  #patch_replicas_env ${name} 1 12000
  #patch_and_wait $name $rsg $unit

  # create unit folder before run-websocket because it may require that folder
  mkdir $result_root/unit${unit}

  sh jenkins-run-websocket.sh

  delete_signalr_service $name $rsg
}

function gen_final_report() {
  sh gen_all_units.sh
  sh publish_report.sh
  sh gen_summary.sh # refresh summary.html in NginxRoot gen_summary
  sh send_mail.sh $HOME/NginxRoot/$result_root/allunits.html
}

function run_units() {
  local grp=$1
  local sku=$2
  local unitlist=$3
  local i
  local name
  create_root_folder

  if [ "$unitlist" == "all" ]
  then
    for i in 1 2 3 4 5 6 7 8 9 10
    do
       name="autoperf"`date +%H%M%S`
       run_unit_benchmark $grp $name $sku $i
    done
  else
    for i in $unitlist
    do
       name="autoperf"`date +%H%M%S`
       run_unit_benchmark $grp $name $sku $unitlist
    done
  fi

  gen_final_report 
}

echo "------jenkins inputs------"
echo "[Units] $UnitList"
echo "[Duration]: $sigbench_run_duration"
echo "[Location]: $Location"

register_signalr_service_dogfood

az_login_ASRS_dogfood

create_group_if_not_exist $target_grp $location

run_units $target_grp $sku "$UnitList"

delete_group $target_grp

unregister_signalr_service_dogfood
