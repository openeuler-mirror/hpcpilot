#
# Copyright (c) Huawei Technologies Co., Ltd. 2022-2022. All rights reserved.
#

#!/usr/bin/env bash
# 关闭防火墙自动化脚本

# 引用公共函数文件
source /${3}/software/tools/hpc_script/common.sh ${3}

# 关闭版本为7或者8的防火墙
function disabled_v78_firewall() {
    if [ -n "$(systemctl status firewalld | grep running)" ]; then
        # 关闭防火墙
        systemctl stop firewalld
        # 关闭开机自启动[需要重新启动]
        systemctl disable firewalld
        # 更新防火墙规则，立即生效
        firewall-cmd --reload &>/dev/null
        log_info "$(get_current_host_info)_close firewall config completed done." false
    else
        log_info "$(get_current_host_info)_firewall has been closed." false
    fi
}

# 防火墙关闭检查结果
function disable_firewall_result() {
    local is_closed=1
    disabled_v78_firewall
    if [ $? -ne 0 ]; then
        log_error "$(get_current_host_info)_failed to close the firewall." false
        is_closed=0
    fi
    echo -e ""
    echo -e "\033[33m======================[7]关闭防火墙配置开始===============================\033[0m"
    if [ "${is_closed}" == "1" ]; then
        echo -e "\033[33m==\033[0m\033[32m  防火墙关闭配置成功                                   [ √ ]\033[0m          \033[33m==\033[0m"
    else
        echo -e "\033[33m==\033[0m\033[31m  防火墙关闭配置失败                                   [ √ ]\033[0m          \033[33m==\033[0m"
    fi
    echo -e "\033[33m======================[7]关闭防火墙配置结束===============================\033[0m"
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
    echo -e "\033[33m==================[7]计算节点关闭防火墙检查结果===========================\033[0m"
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
    echo -e "\033[33m==================[7]计算节点关闭防火墙检查结果===========================\033[0m"
}
# 脚本执行合法性检查，无检查项直接返回0
function required_check() {
    return 0
}

############### 主函数入口 ###############
# 参数${1}表示手动执行脚本还是自动执行脚本方式
# 参数${2}是否开启DEBUG模式
# 参数${3}脚本所在的根目录（share workspace）
is_manual_script=${1}
is_open_debug=${2}
if [ -z "${is_manual_script}" ]; then
    is_manual_script=true
fi
if [ -z "${is_open_debug}" ]; then
    is_open_debug=false
fi
manual_script_action ${is_manual_script} ${is_open_debug} required_check check_firewall_result disable_firewall_result