#
# Copyright (c) Huawei Technologies Co., Ltd. 2022-2022. All rights reserved.
#

#!/usr/bin/env bash
######################################################################
# 脚本描述：检查、关闭防火墙自动化脚本                                       #
# 注意事项：无                                                          #
######################################################################

# set -x
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


# 关闭版本为7或者8的防火墙
function disabled_v78_firewall() {
    if [ -n "$(systemctl status firewalld | grep running)" ]; then
        # 关闭防火墙
        systemctl stop firewalld
        # 更新防火墙规则，立即生效
        firewall-cmd --reload >> ${operation_log_path}/access_all.log 2>&1
        log_info "Disabling the firewall is complete." false
    else
        log_info "Firewall has been closed." false
    fi
    if [[ "$(systemctl list-unit-files | grep firewalld.service)" =~ "enabled" ]]; then
        # 闭开机自启动
        systemctl disable firewalld >> ${operation_log_path}/access_all.log 2>&1
        log_info "Firewall automatic startup is complete." false
    else
        log_info "Firewall automatic startup is disabled." false
    fi
}

# 检查防火墙配置
function check_firewall_config() {
    local ret_close_code="0"
    local ret_auto_code="0"
    local firewall_status=$(systemctl status firewalld | grep running)
    if [ -n "${firewall_status}" ]; then
        ret_close_code="1"
    fi
    local is_auto_start=$(systemctl list-unit-files | grep firewalld.service)
    if [[ ${is_auto_start} =~ "enabled" ]]; then
        ret_auto_code="1"
    fi
    ret_info=(${ret_close_code} ${ret_auto_code})
    echo ${ret_info[@]}
}

# 检查防火墙关闭
function check_firewall_result() {
    echo -e ""
    echo -e "\033[33m==================[7]防火墙关闭配置检查结果===============================\033[0m"
    local return_msg=($(check_firewall_config))
    if [ "${return_msg[0]}" == "0" ]; then
        echo -e "\033[33m==\033[0m\033[32m  计算节点关闭防火墙检查果正常                         [ √ ]\033[0m          \033[33m==\033[0m"
        if [ "${return_msg[1]}" == "0" ]; then
            echo -e "\033[33m==\033[0m\033[32m  防火墙开机自启动配置正常                             [ √ ]\033[0m          \033[33m==\033[0m"
        else
            echo -e "\033[33m==\033[0m\033[31m  防火墙开机自启动配置异常                             [ X ]\033[0m          \033[33m==\033[0m"
        fi
    else
        echo -e "\033[33m==\033[0m\033[31m  计算节点关闭防火墙检查果异常                         [ X ]\033[0m          \033[33m==\033[0m"
    fi
    echo -e "\033[33m==================[7]防火墙关闭配置检查结果===============================\033[0m"
}

# 防火墙关闭检查结果
function disable_firewall_result() {
    disabled_v78_firewall
    if [ $? -ne 0 ]; then
        log_error "Failed to close the firewall." false
    fi
    check_firewall_result
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
manual_script_action ${is_manual_script} ${is_open_debug} required_check check_firewall_result disable_firewall_result ${4}