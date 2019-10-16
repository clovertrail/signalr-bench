function extract_username_from_signalr_hosts()
{
  local signalr_hosts=signalr_hosts
  local line nospaces leading login_user
  local re="^#"
  while read line
  do
    # remove leading and tailing spaces
    nospaces=`echo "$line"|awk '{$1=$1; print}'`
    leading=`echo "$nospaces"|cut -c1`
    if [[ "$leading" =~ $re ]]; then
       continue
    fi
    login_user=`echo "leading"|awk -F "ansible_user=" '{print $2}'`
  done < $signalr_hosts
  echo "$login_user"
}

function install_go()
{
  local install_go_yaml=install_config_go.yaml
  local login_user=$(extract_username_from_signalr_hosts)
  local default_user="honzhan"
  if [ "$login_user" != "" ] || [ "$login_user" != "$default_user" ]; then
     sed -i "s/$default_user/$login_user/g" $install_go_yaml
  fi
  ansible-playbook -i signalr_hosts $install_go_yaml
}

ansible-playbook -i signalr_hosts change_sh_softlink.yaml
ansible-playbook -i signalr_hosts pam_limits.yaml
ansible-playbook -i signalr_hosts sysctl.yaml
install_go
ansible-playbook -i signalr_hosts install_package.yaml
ansible-playbook -i signalr_hosts install_kubectl.yaml
ansible-playbook -i signalr_hosts run_install_az.yaml
ansible-playbook -i signalr_hosts run_install_dotnet3.yaml
