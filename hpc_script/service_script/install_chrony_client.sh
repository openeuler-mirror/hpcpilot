#!/usr/bin/env bash

######################################################################
# 脚本描述：安装配置Chrony客户端自动化脚本                                   #
# 注意事项：无                                                          #
######################################################################

# 引用公共函数文件开始
if [ "${1}" == "opt" ]; then
    # 定义脚本文件、配置文件存放目录
    base_directory=/${1}/hpcpilot/hpc_script
else
    # 定义脚本文件、配置文件存放目录
    base_directory=/${1}/software/tools/hpc_script
fi
source ${base_directory}/common.sh ${1}
# 引用公共函数文件结束

#ntp服务端IP
ntp_server_ip=$(get_ini_value service_conf ntp_server_ip)

ansible-playbook -e "ntp_server_ip=${ntp_server_ip}" ${base_directory}/service_script/install_chrony_cli.yml
