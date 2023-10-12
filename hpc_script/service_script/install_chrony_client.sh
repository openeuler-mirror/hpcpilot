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

#确定要执行安装chrony客户端的hosts，规则如下：
#若为扩容场景，则执行扩容节点中的chrony客户端节点
#若为非扩容场景，则执行chrony客户端的节点
if [ "$(check_run_expansion)" == "1" ]; then
    play_hosts="expansion : ntp_client"
else
    play_hosts="ntp_client"
fi
ansible-playbook ${base_directory}/service_script/install_chrony_cli.yml -e "ntp_server_ip=${ntp_server_ip}" -e "hosts=${play_hosts}"
