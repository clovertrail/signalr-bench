#!/bin/bash
. ./func_env.sh

function single_run() {
  sh jenkins-run-websocket.sh
}

function multiple_try_run() {
  local connection_string=$1
  local connection_number=$2
  local step_number=$3
  local concurrent_number=$4
  local duration=$5
  local max_try=$6
  local i=0
  local use_https
  if [[ $connection_string = *"https://"* ]]
  then
     use_https=1
  else
     use_https=0
  fi

  while [ $i -lt $max_try ]
  do
cat << EOF > jenkins_env.sh
sigbench_run_duration=$duration
connection_concurrent=$concurrent_number
connection_string="$connection_string"
connection_number=$connection_number
send_number=$connection_number
bench_type_list="c${connection_number}"
use_https=$use_https
EOF
    mkdir $result_root/c$connection_number
    single_run
    if [ -e $result_root/$error_mark_file ]
    then
       echo "!!!Stop trying since error occurs"
       return
    fi
    connection_number=`expr $connection_number + $step_number`
    i=`expr $i + 1`
  done
}

create_root_folder

echo "-------your inputs------"
echo "[ConnectionString]: $ConnectionString"
echo "[BaseConnectionNumber]: $BaseConnectionNumber"
echo "[ConnectionSteps]: $ConnectionSteps"
echo "[ConcurrentConnectionNumber]: $ConcurrentConnectionNumber"
echo "[Duration]: $Duration"
echo "[MaxTry]: $MaxTry"

multiple_try_run $ConnectionString $BaseConnectionNumber $ConnectionSteps $ConcurrentConnectionNumber $Duration $MaxTry

sh gen_all_report.sh # gen_all_report
sh publish_report.sh 
sh gen_summary.sh # refresh summary.html in NginxRoot gen_summary
sh send_mail.sh $HOME/NginxRoot/$result_root/all.html
