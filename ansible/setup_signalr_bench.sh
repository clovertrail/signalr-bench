ansible-playbook -i signalr_hosts change_sh_softlink.yaml
ansible-playbook -i signalr_hosts pam_limits.yaml
ansible-playbook -i signalr_hosts sysctl.yaml
ansible-playbook -i signalr_hosts install_config_go.yaml
ansible-playbook -i signalr_hosts install_package.yaml
ansible-playbook -i signalr_hosts install_kubectl.yaml
ansible-playbook -i signalr_hosts run_install_az.yaml
ansible-playbook -i signalr_hosts run_install_dotnet2_2.yaml
