#!/bin/bash

if [ $# -ne 1 ]
then
  echo "Usage: resourceName"
  exit 1
fi

resName=$1

function k8s_query() {
  local config_file=$1
  local kubeId=`kubectl get deploy -o=json --selector resourceName=$resName --kubeconfig=${config_file}|jq '.items[0].metadata.labels.resourceKubeId'|tr -d '"'`
  local len=`kubectl get pod -o=json --selector resourceKubeId=$kubeId --kubeconfig=${config_file}|jq '.items|length'`
  if [ $len == "0" ]
  then
     return
  fi
  i=0
  while [ $i -lt $len ]
  do
     kubectl get pod -o=json --selector resourceKubeId=$kubeId --kubeconfig=${config_file}|jq ".items[$i].metadata.name"|tr -d '"'
     i=`expr $i + 1`
  done
}

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
