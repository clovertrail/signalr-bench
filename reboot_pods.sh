#!/bin/bash

. ./kubectl_utils.sh

if [ $# -ne 1 ]
then
  echo "Specify service_name"
  exit 1
fi
service_name=$1
restart_all_pods $service_name
