#!/bin/bash

. ./kubectl_utils.sh

if [ $# -ne 1 ]
then
  echo "Usage: resourceName"
  exit 1
fi

resName=$1

function query() {
  local config_file=kvsignalrdevseasia.config
  local result=$(k8s_query $config_file)
  if [ "$result" == "" ]
  then
     config_file=srdevacsrpd.config
     k8s_query $config_file
  else
     echo "$result"
  fi
}

set +x

query

set -x
