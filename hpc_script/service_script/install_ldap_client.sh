#!/bin/bash


# 引用公共函数文件开始
# root_dir=$(echo "$(pwd)" | awk '{split($1,arr,"/");print arr[2]}')
source /${1}/software/tools/hpc_script/common.sh ${1}
# 引用公共函数文件结束


# playbook脚本目录
playbook_dir=$(get_ini_value basic_conf basic_shared_directory /share)/software/tools/hpc_script/service_script
# openldap服务端IP（HA场景为虚拟IP）
ldap_server_ip=$(get_ini_value service_conf virtual_ldap_server_ip $(get_ini_value service_conf master_ldap_server_ip))


ansible-playbook -e "ldap_server_ip=$ldap_server_ip" $playbook_dir/install_ldap_cli_TLS.yml
