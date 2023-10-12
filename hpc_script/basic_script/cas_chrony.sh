#
# Copyright (c) Huawei Technologies Co., Ltd. 2022-2022. All rights reserved.
#

#!/usr/bin/env bash
######################################################################
# 脚本描述：检查chrony客户端状态自动化脚本                                       #
# 注意事项：无                                                          #
######################################################################

# 引用公共函数文件开始
if [ "${3}" == "opt" ]; then
    # 定义脚本文件、配置文件存放目录
    base_directory=/${3}/hpcpilot/hpc_script
else
    # 定义脚本文件、配置文件存放目录
    base_directory=/${3}/software/tools/hpc_script
fi
source ${base_directory}/common.sh ${3}
# 引用公共函数文件结束

# 获取配置文件NTP服务端IP地址
ntp_server_ip=$(get_ini_value basic_conf ntp_server_ip)
# 获取配置文件NTP服务端主机名
ntp_server_name=$(cat /etc/hosts |grep "${ntp_server_ip}" | awk '{print$2}')
if [ "$ntp_server_name" == "" ]; then
  ntp_server_name=$(ssh ${ntp_server_ip} hostname)
fi

# ldap检查结果打印输出
function check_chrony_result() {
    echo -e ""
    echo -e "\033[33m==================[13]计算节点chrony检查结果=====================\033[0m"
    if [ "$(rpm -qa | grep "chrony")" != "" ]; then
        echo -e "\033[33m==\033[0m\033[32m  chrony服务已安装                                     [ √ ]\033[0m          \033[33m==\033[0m"
        if [ "$(systemctl status chronyd.service | grep -o "active (running)")" != "" ]; then
                echo -e "\033[33m==\033[0m\033[32m  chronyd.service服务已启动                            [ √ ]\033[0m          \033[33m==\033[0m"
        else
                echo -e "\033[33m==\033[0m\033[31m  chronyd.service服务未启动                            [ X ]\033[0m          \033[33m==\033[0m"
        fi
        current_chrony_server_ip=$(chronyc sources |awk 'NR==4' |awk '{print $2}')
        if [ "${current_chrony_server_ip}" == "${ntp_server_ip}" ] || [ "${current_chrony_server_ip}" == "${ntp_server_name}" ]; then
                echo -e "\033[33m==\033[0m\033[32m  chrony时钟已同步                                     [ √ ]\033[0m          \033[33m==\033[0m"
        else
                echo -e "\033[33m==\033[0m\033[31m  chrony时钟未同步                                     [ X ]\033[0m          \033[33m==\033[0m"
        fi
    else
        echo -e "\033[33m==\033[0m\033[31m  chrony服务未安装                                     [ X ]\033[0m          \033[33m==\033[0m"
    fi
    echo -e "\033[33m==================[13]计算节点chrony检查结果=====================\033[0m"
}

# 脚本执行合法性检查，无检查项直接返回0
function required_check() {
    return 0
}

############### 主函数入口 ###############
# 参数${1}表示手动执行脚本还是自动执行脚本方式
# 参数${2}是否开启DEBUG模式
# 参数${3}脚本所在的根目录（share workspace）
# 参数${4}批量执行标识(true or false)
is_manual_script=${1}
is_open_debug=${2}
if [ -z "${is_manual_script}" ]; then
    is_manual_script=true
fi
if [ -z "${is_open_debug}" ]; then
    is_open_debug=false
fi
manual_script_action ${is_manual_script} ${is_open_debug} required_check check_chrony_result ${4}