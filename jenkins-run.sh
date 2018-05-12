#!/bin/bash
. ./jenkins_env.sh

# jenkins normalized input

echo "-------jenkins normalize your inputs------"
echo "[ConnectionString]: $connection_string"
echo "[ClientConnectionNumber]: $connection_number"
echo "[ConcurrentConnectionNumber]: $connection_concurrent"
echo "[SendNumber]: $send_number"
echo "[Duration]: $sigbench_run_duration"

export result_root=`date +%Y%m%d%H%M%S`
mkdir $result_root

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
sh gen_html.sh # gen_html
sh gen_all_report.sh # gen_all_report
sh publish_report.sh 
sh gen_summary.sh # refresh summary.html in NginxRoot gen_summary
sh send_mail.sh $HOME/NginxRoot/$result_root/all.html
