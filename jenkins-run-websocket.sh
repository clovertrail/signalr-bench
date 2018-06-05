#!/bin/bash
. ./jenkins_env.sh

MaxConnectionNumber=20000

if [ "$connection_string" == "" ]
then
   echo "connection string must not be empty!"
   exit 1
fi

if [ "$connection_number" == "" ]
then
   echo "connection number must not be empty"
   exit 1
fi

if [ $connection_number -gt $MaxConnectionNumber ]
then
   echo "connection number's maximum limit is $MaxConnectionNumber"
   exit 1
fi

if [ $connection_number -lt 1 ]
then
   echo "connection number's minimum limit is 1"
   exit 1
fi

if [ "$send_number" == "" ]
then
   echo "Warning: send number is empty, so the default send number will be set to connection number"
   send_number=$connection_number
fi

if [ $send_number -gt $connection_number ]
then
   echo "Warning: currently we did not support sending number larger than connection number, so set it to be connection number"
   send_number=$connection_number
fi
# jenkins normalized input

echo "-------jenkins normalize your inputs------"
echo "[ConnectionString]: $connection_string"
echo "[ClientConnectionNumber]: $connection_number"
echo "[ConcurrentConnectionNumber]: $connection_concurrent"
echo "[SendNumber]: $send_number"
echo "[Duration]: $sigbench_run_duration"

. ./func_env.sh

start_sdk_server $connection_string

err_check=`grep -i "error" ${result_dir}/${app_running_log}`
if [ "$err_check" != "" ]
then
   echo "Fail to start app server: $err_check"
   exit 1
fi

gen_jenkins_command_config

. ./kubectl_utils.sh

service_name=$(extract_servicename_from_connectionstring $connection_string)
if [ "$service_name" != "" ]
then
   start_connection_tracking $service_name
fi

sh run_websocket.sh

if [ "$service_name" != "" ]
then
   if [[ $bench_type_list == unit* ]] && [ -d $result_root/$bench_type_list ]
   then
     stop_connection_tracking $service_name $result_root/$bench_type_list
     copy_syslog $service_name $result_root/$bench_type_list
   else
     stop_connection_tracking $service_name $result_root
     copy_syslog $service_name $result_root
   fi
fi

sh gen_html.sh $connection_string # gen_html
