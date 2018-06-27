#!/bin/bash
. ./jenkins_env.sh

# jenkins normalized input

echo "-------jenkins normalize your inputs------"
echo "[ServerHost]: $ServerHost"
echo "[ClientConnectionNumber]: $connection_number"
echo "[ConcurrentConnectionNumber]: $connection_concurrent"
echo "[SendNumber]: $send_number"
echo "[Duration]: $sigbench_run_duration"
echo "[UseHttps]: $UseHttps"

. ./func_env.sh

create_root_folder

gen_jenkins_command_config

sh run_websocket.sh
sh gen_html.sh

gen_final_report
