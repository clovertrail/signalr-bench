#!/bin/bash
. ./utils.sh

function create_signalr_service()
{
  local rsg=$1
  local name=$2
  local sku=$3
  local unitCount=$4
  local signalrHostName
  signalrHostName=$(az signalr create \
     --name $name                     \
     --resource-group $rsg            \
     --sku $sku                       \
     --unit-count $unitCount          \
     --query hostName                 \
     -o tsv)
  echo "$signalrHostName"
}

function check_signalr_service()
{
  local target_service=$1
  local existing=`az signalr list --query [*].hostName --output table|grep "$target_service"`
  if [ "$existing" != "" ]
  then
     echo "1"
  else
     echo "0"
  fi
}

function query_connection_string()
{
  local signarl_service_name=$1
  local rsg=$2
  local signalrHostName=`az signalr list --query [*].hostName --output table|grep "$signarl_service_name"`
  if [ "$signalrHostName" == "" ]
  then
     echo ""
     return
  fi

  local accessKey=`az signalr key list --name $signarl_service_name --resource-group $rsg --query primaryKey -o tsv`
  echo "Endpoint=https://${signalrHostName};AccessKey=${accessKey}"
}

function delete_signalr_service()
{
  local rsg=$1
  az group delete --name $rsg -y
}
