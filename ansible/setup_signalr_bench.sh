
ansible-playbook -i signalr_hosts pam_limits.yaml
ansible-playbook -i signalr_hosts install_config_go.yaml
ansible-playbook -i signalr_hosts git_clone_websocket.yaml
ansible-playbook -i signalr_hosts build_websocket.yaml
ansible-playbook -i signalr_hosts git_clone_azuresignalrchatsample.yaml
ansible-playbook -i signalr_hosts install_package.yaml
ansible-playbook -i signalr_hosts install_kubectl.yaml
ansible-playbook -i signalr_hosts build_azuresignalrsample.yaml
