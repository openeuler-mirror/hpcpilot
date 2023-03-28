#!/usr/bin/env bash


# 引用公共函数文件开始
# root_dir=$(echo "$(pwd)" | awk '{split($1,arr,"/");print arr[2]}')
source /${1}/software/tools/hpc_script/common.sh ${1}
# 引用公共函数文件结束


# playbook脚本目录
playbook_dir=$(get_ini_value basic_conf basic_shared_directory /share)/software/tools/hpc_script/service_script
#ntp服务端IP
ntp_server_ip=$(get_ini_value service_conf ntp_server_ip)


ansible-playbook $playbook_dir/install_ntp_server.yml
