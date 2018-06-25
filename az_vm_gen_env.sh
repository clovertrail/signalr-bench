#!/bin/bash
g_gen_global_env_for_creating_vm_from_img() {
  local myimg_name=$1
  local myimg_rsg_name=$2
  local target_rsg_name=$3
  local dns_prefix=$4
  local ssh_user=$5
  local ssh_port=$6
  local vm_size=$7
  local total_vm_count=$8
cat <<EOF > vm_env.sh
#!/bin/bash
# customized image. The VM location must be the same as image
g_total_vms=$total_vm_count
g_myimg_name="$myimg_name"
g_myimg_rsg_name="$myimg_rsg_name"

g_resource_group="$target_rsg_name"
g_dns_prefix="$dns_prefix"
g_ssh_user=$ssh_user
g_ssh_port=$ssh_port
g_ssh_pubkey_file=$HOME/.ssh/id_rsa.pub
g_ssh_private_file=$HOME/.ssh/id_rsa
g_vm_size="$vm_size"
g_vm_wait_timeout=240
EOF
}
