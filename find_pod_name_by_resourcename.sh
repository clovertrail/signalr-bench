#!/bin/bash

config_file=kvsignalrdevseasia.config

if [ $# -ne 1 ]
then
  echo "Usage: resourceName"
  exit 1
fi

resName=$1
kubeId=`kubectl get deploy -o=json --selector resourceName=$resName --kubeconfig=${config_file}|jq '.items[0].metadata.labels.resourceKubeId'|tr -d '"'`
len=`kubectl get pod -o=json --selector resourceKubeId=$kubeId --kubeconfig=${config_file}|jq '.items|length'`
echo "Pods: $len"
i=0
while [ $i -lt $len ]
do
  kubectl get pod -o=json --selector resourceKubeId=$kubeId --kubeconfig=${config_file}|jq ".items[$i].metadata.name"|tr -d '"'
  i=`expr $i + 1`
done
