#!/bin/bash
. ./kubectl_utils.sh

if [ $# -ne 2 ]
then
  echo "Specify <resName> <limitNo>"
  exit 1
fi

resName=$1
limitNo=$2
patch_connection_throttling_env $resName $limitNo
