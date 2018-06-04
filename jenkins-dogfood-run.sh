#!/bin/bash
. ./az_signalr_service.sh

. ./func_env.sh

target_grp="honzhanautoperf"
location=$Location
asrs_name="honzhanautoservice"
sku="Basic_DS2"

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
  local name=$2
  local sku=$3
  local unitlist=$4
  local i

  create_root_folder

  if [ "$unitlist" == "all" ]
  then
    for i in 1 2 3 4 5 6 7 8 9 10
    do
       run_unit_benchmark $grp $name $sku $i
    done
  else
    run_unit_benchmark $grp $name $sku $unitlist
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

run_units $target_grp $asrs_name $sku $UnitList

delete_group $target_grp

unregister_signalr_service_dogfood
