function get_k8s_deploy_name() {
  local resName=$1
  local config_file=$2
  local len=`kubectl get deploy -o=json --selector resourceName=$resName --kubeconfig=${config_file}|jq '.items|length'`
  if [ $len -eq 0 ]
  then
    return
  fi
  local deployName=`kubectl get deploy -o=json --selector resourceName=$resName --kubeconfig=${config_file}|jq '.items[0].metadata.name'|tr -d '"'`
  echo $deployName
  #kubectl get deploy $deployName -o=json  --kubeconfig=$config_file
}

function update_k8s_deploy_replicas() {
  local deploy_name=$1
  local target_replicas=$2
  local config_file=$3
  kubectl patch deployment $deploy_name --type=json -p="[{'op': 'replace', 'path': '/spec/replicas', 'value': $target_replicas}]" --kubeconfig=$config_file
}

function update_k8s_deploy_env_connections() {
  local env_name
  local deploy_name=$1
  local connections_limit=$2
  local config_file=$3
  local env_len=`kubectl get deployment $deploy_name -o=json --kubeconfig=${config_file}|jq '.spec.template.spec.containers[0].env|length'`
  if [ $env_len -eq 18 ]
  then
    env_name=`kubectl get deployment $deploy_name -o=json --kubeconfig=${config_file}|jq '.spec.template.spec.containers[0].env[17].name'|tr -d '"'`
    if [ "$env_name" == "ConnectionCountLimit" ]
    then
      kubectl patch deployment $deploy_name --type=json -p="[{'op': 'replace', 'path': '/spec/template/spec/containers/0/env/17/value', 'value': '$connections_limit'}]" --kubeconfig=$config_file
    fi

    env_name=`kubectl get deployment $deploy_name -o=json --kubeconfig=${config_file}|jq '.spec.template.spec.containers[0].env[16].name'|tr -d '"'`
    if [ "$env_name" == "MaxConcurrentUpgradedConnections" ]
    then
      kubectl patch deployment $deploy_name --type=json -p="[{'op': 'replace', 'path': '/spec/template/spec/containers/0/env/16/value', 'value': '$connections_limit'}]" --kubeconfig=$config_file
    fi

    env_name=`kubectl get deployment $deploy_name -o=json --kubeconfig=${config_file}|jq '.spec.template.spec.containers[0].env[15].name'|tr -d '"'`
    if [ "$env_name" == "MaxConcurrentConnections" ]
    then
      kubectl patch deployment $deploy_name --type=json -p="[{'op': 'replace', 'path': '/spec/template/spec/containers/0/env/15/value', 'value': '$connections_limit'}]" --kubeconfig=$config_file
    fi
  fi
}

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

function update_k8s_deploy_cpu_limits() {
  local deploy_name=$1
  local cpu_limit=$2
  local config_file=$3
  kubectl patch deployment $deploy_name --type=json -p="[{'op': 'replace', 'path': '/spec/template/spec/containers/0/resources/limits/cpu', 'value': '$cpu_limit'}]" --kubeconfig=$config_file
}

function update_k8s_deploy_cpu_request() {
  local deploy_name=$1
  local cpu_limit=$2
  local config_file=$3
  kubectl patch deployment $deploy_name --type=json -p="[{'op': 'replace', 'path': '/spec/template/spec/containers/0/resources/requests/cpu', 'value': '$cpu_limit'}]" --kubeconfig=$config_file
}

function update_k8s_deploy_memory_limits() {
  local deploy_name=$1
  local memory_limit=$2
  local config_file=$3
  kubectl patch deployment $deploy_name --type=json -p="[{'op': 'replace', 'path': '/spec/template/spec/containers/0/resources/limits/memory', 'value': '$memory_limit'}]" --kubeconfig=$config_file
}

function patch_replicas() {
  local resName=$1
  local replicas=$2
  local config_file=kvsignalrdevseasia.config
  local result=$(get_k8s_deploy_name $resName $config_file)
  if [ "$result" == "" ]
  then
     config_file=srdevacsrpd.config
     result=$(get_k8s_deploy_name $resName $config_file)
  fi
  #echo "$result"
  update_k8s_deploy_replicas $result $replicas $config_file
}

# resource_name, replicas, cpu_limit, cpu_req, mem_limit, connect_limit
function patch() {
  local resName=$1
  local replicas=$2
  local cpu_limit=$3
  local cpu_req=$4
  local mem_limit=$5
  local connect_limit=$6
  local config_file=kvsignalrdevseasia.config
  local result=$(get_k8s_deploy_name $resName $config_file)
  if [ "$result" == "" ]
  then
     config_file=srdevacsrpd.config
     result=$(get_k8s_deploy_name $resName $config_file)
  fi
  #echo "$result"
  update_k8s_deploy_replicas $result $replicas $config_file

  update_k8s_deploy_cpu_limits $result "$cpu_limit" $config_file

  update_k8s_deploy_cpu_request $result "$cpu_req" $config_file

  update_k8s_deploy_memory_limits $result "${mem_limit}Mi" $config_file

  update_k8s_deploy_env_connections $result "${connect_limit}" $config_file
}
