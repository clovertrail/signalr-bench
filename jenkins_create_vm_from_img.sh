#!/bin/bash

# parameters were saved in a config file: VM.env
#Alias=
#VMOS=
#VMSize=
#SSHPlublicKey=
#WindowsPassword=
#VMCount=
#TargetResouceGroup=
#SSHPort=
#EmailFile=
#VMNamePostfix=

######

if [ ! -e VM.env ]
then
  echo "Specify VM.env file"
  exit 1
fi

. ./VM.env

SSHPort=22
RDPPort=3389

function EchoParameters() {
echo "==Jenkins input=="
echo "[Alias]: $Alias"
echo "[VMOS]: $VMOS"
echo "[VMSize]: $VMSize"
echo "[SSHPublicKey]: $SSHPubKey"
echo "[WindowsPassword]: $WindowsPassword"
echo "[VMCount]: $VMCount"
echo "[TargetResourceGroup]: $ResourceGroupName"
echo "[SSHPort]: $SSHPort"
echo "[VMNamePostfix]: $VMNamePostfix"
echo "[EmailFile]: $EmailFile"
}

function SetGlobalEnv() {
local postfix
if [ "$VMNamePostfix" == "date" ]
then
  postfix=`date +%Y%m%d%H%M%S`
else
  postfix="$VMNamePostfix"
fi

local t_resgrp_name=${ResourceGroupName}
if [ "${t_resgrp_name}" == "" ]
then
  t_resgrp_name=${Alias}${postfix}"rsg"
fi
export ResourceGroup=${t_resgrp_name} # used for on-demand VM creation
export VMPrefix=${Alias}${postfix}
export VMHostFiles=${Alias}${postfix}"_host.txt"
export MaxRetry=5
}

function eastus_Windows() {
   echo "null" "null"
}

function eastus_Linux() {
   echo "honzhaneus" "hzbencheusimg"
}

function southeastasia_Windows() {
   echo "honzhanperfsea" "hzwin2k16-image"
}

function southeastasia_Linux() {
   echo "honzhanperfsea" "hzbenchseaimg"
}

function westeurope_Windowes() {
   echo "null" "null"
}

function westeurope_Linux() {
   echo "honzhanweu" "hzbenchweuimg"
}

function westus2_Windows() {
   echo "null" "null"
}

function westus2_Linux() {
   echo "honzhanwus2" "hzbenchwus2img"
}

function CreateAzureVm() {
EchoParameters
SetGlobalEnv
cd AzureAccess
local func=${Region}_${VMOS}
local resources=`eval $func`
echo "resouces: $resources"
local ImgResourceGroup=`echo "$resources"|awk '{print$ 1}'`
local ImgName=`echo "$resources"|awk '{print$ 2}'`

if [ "$ImgResourceGroup" == "null" ] || [ "$ImgName" == "null" ]
then
   echo "The configuration for '${Region}_${VMOS}' is missing"
   exit 1
fi

echo "image resource group: '$ImgResourceGroup'"
echo "image name: '$ImgName'"
if [ "$VMOS" == "Windows" ]
then
  dotnet run -- -a ../signalr_dev.auth \
              -i ${ImgResourceGroup} \
              -n ${ImgName} -s $ResourceGroup \
              -p ${VMPrefix} -S ${VMSize} \
              -t 2 \
              -P ${WindowsPassword} -c ${VMCount} \
              -u ${Alias} -O ${VMHostFiles} \
              -A True -m accelerated_network_vmsize.txt -z ${RDPPort} -r ${MaxRetry}
else
  if [ "$SSHPubKey" == "" ]
  then
    echo "!!Missing ssh public key!!"
    exit
  fi
  echo "$SSHPubKey" > /tmp/${Aliasa}_ssh_pub_key
  virNetOpt=""
  subnetOpt=""
  if [ "$VirtualNetwork" != "" ]
  then
     virNetOpt="--virtual-network $VirtualNetwork"
  fi
  if [ "$Subnet" != "" ]
  then
     subnetOpt="--subnet $Subnet"
  fi
  echo dotnet run -- -a ../signalr_dev.auth \
              -i ${ImgResourceGroup} \
              -n ${ImgName} -s $ResourceGroup \
              -p ${VMPrefix} -S ${VMSize} \
              -H /tmp/${Aliasa}_ssh_pub_key -c ${VMCount} \
              -u ${Alias} -O ${VMHostFiles}\
              -A True -m accelerated_network_vmsize.txt -z $SSHPort -r ${MaxRetry} ${virNetOpt} ${subnetOpt}
  dotnet run -- -a ../signalr_dev.auth \
              -i ${ImgResourceGroup} \
              -n ${ImgName} -s $ResourceGroup \
              -p ${VMPrefix} -S ${VMSize} \
              -H /tmp/${Aliasa}_ssh_pub_key -c ${VMCount} \
              -u ${Alias} -O ${VMHostFiles}\
              -A True -m accelerated_network_vmsize.txt -z $SSHPort -r ${MaxRetry} ${virNetOpt} ${subnetOpt}
fi
vm_host=`cat ${VMHostFiles}`
cd -

if [ -e $EmailFile ]
then
  rm $EmailFile
fi

cat << EOF > $EmailFile
========================================
Your VM information:

Subscription: "Azure SignalR Service DevINT"

Resource Group: ${ResourceGroup}
VMSize:     $VMSize
VMCount:    $VMCount
OS Type:    ${VMOS}
Host name:  ${vm_host}
Login User: ${Alias}
Windows Pass: ${WindowsPassword}
Linux Port: $SSHPort
Windows RDPPort: ${RDPPort}
========================================
EOF
}

CreateAzureVm
