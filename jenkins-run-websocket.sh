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

sh run_websocket.sh
sh gen_html.sh $connection_string # gen_html
