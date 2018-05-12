#!/bin/bash
. ./servers_env.sh

## set the SignalR bench configuration ##
bench_name_list="echo" #"broadcast" #"echo broadcast"
bench_type_list="service" #"selfhost service"
bench_codec_list="json" #"json msgpack"
#bench_name="echo"      # broadcast, echo
#bench_type="selfhost"  # selfhost, service
#bench_codec="json"     # json, msg
if [ "$bench_type" == "service" ]
then
	bench_config_endpoint=${bench_service_server}:${bench_service_port}
else
	bench_config_endpoint=${bench_app_pub_server}:${bench_app_port}
fi
bench_config_hub="chat"
use_https=1
sigbench_run_duration=240 #second running for benchmark
# check Jenkins' builtin variables
if [ "$NODE_NAME" != "" ] && [ "$JOB_NAME" != "" ]
then
  # replace the $sigbench_run_duration, $use_https and $bench_config_hub
  if [ "$__jenkins_env__" == "" ]
  then
     . ./jenkins_env.sh
  fi
fi
