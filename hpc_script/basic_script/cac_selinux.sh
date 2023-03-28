#
# Copyright (c) Huawei Technologies Co., Ltd. 2022-2022. All rights reserved.
#

#!/usr/bin/env bash
# Selinux的主要作用就是最大限度地减小系统中服务进程可访问的资源
# 关闭selinux安全子系统内核模块自动化脚本

# 引用公共函数文件开始
source /${3}/software/tools/hpc_script/common.sh ${3}
# 引用公共函数文件结束

# 配置文件路径
config_file_path=/etc/selinux/config
# 定义配置文件关键字
cons_selinux_key="SELINUX"
cons_selinux_value="disabled"
cons_SELINUXTYPE_key="SELINUXTYPE"
cons_SELINUXTYPE_value="targeted"

# 检查配置是否正确
function check_selinux() {
    local ret_file_code="0"
    local ret_selinux_code="0"
    local ret_selinux_type_code="0"
    # 检查文件是否存在
    if [ $(is_file_exist ${config_file_path}) == "1" ]; then
        ret_file_code="1"
        echo ${ret_file_code}
        return
    fi
    # 检查SELINUX值设置是否正确
    if [ $(get_property_value "${config_file_path}" ${cons_selinux_key}) != ${cons_selinux_value} ]; then
        ret_selinux_code="1"
    fi
    # 检查SELINUXTYPE值设置是否正确
    if [ $(get_property_value "${config_file_path}" ${cons_SELINUXTYPE_key}) != ${cons_SELINUXTYPE_value} ]; then
        ret_selinux_type_code="1"
    fi
    ret_info=(${ret_file_code} ${ret_selinux_code} ${ret_selinux_type_code})
    echo ${ret_info[@]}
}

# selinux检查结果输出打印
function check_selinux_result() {
    echo -e ""
    echo -e "\033[33m==================[6]计算节点关闭selinux检查结果==========================\033[0m"
    local return_msg=($(check_selinux))
    if [ "${return_msg[0]}" == "0" ]; then
        if [ "${return_msg[1]}" == "0" ]; then
            echo -e "\033[33m==\033[0m\033[32m  配置文件SELINUX值设置正确                            [ √ ]\033[0m          \033[33m==\033[0m"
        else
            echo -e "\033[33m==\033[0m\033[31m  配置文件SELINUX值设置错误                            [ X ]\033[0m          \033[33m==\033[0m"
        fi
        if [ "${return_msg[2]}" == "0" ]; then
            echo -e "\033[33m==\033[0m\033[32m  配置文件SELINUXTYPE值设置正确                        [ √ ]\033[0m          \033[33m==\033[0m"
        else
            echo -e "\033[33m==\033[0m\033[31m  配置文件SELINUXTYPE值设置错误                        [ X ]\033[0m          \033[33m==\033[0m"
        fi
    else
        echo -e "\033[33m==\033[0m\033[31m  配置文件[${config_file_path}]未找到                  [ X ]\033[0m          \033[33m==\033[0m"
    fi
    echo -e "\033[33m==================[6]计算节点关闭selinux检查结果==========================\033[0m"
}

# 关闭selinux
function close_selinux() {
    # 检查配置文件是否存在
    if [ $(is_file_exist ${config_file_path}) != "0" ]; then
        log_warn "$(get_current_host_info)_${config_file_path} file doesn't exist, creating and config..." false
        # 创建文件并赋予权限
        touch ${config_file_path}
        chmod 775 ${config_file_path}
    fi
    
    # 设置SELINUX值为disabled
    if [ $(get_property_value "${config_file_path}" ${cons_selinux_key}) != ${cons_selinux_value} ]; then
        modify_property_value ${config_file_path} ${cons_selinux_key} ${cons_selinux_value}
    else
        log_warn "$(get_current_host_info)_[${cons_selinux_key}] value has been configured." false
    fi
    
    # 设置SELINUXTYPE值为targeted
    if [ $(get_property_value "${config_file_path}" ${cons_SELINUXTYPE_key}) != ${cons_SELINUXTYPE_value} ]; then
        modify_property_value ${config_file_path} ${cons_SELINUXTYPE_key} ${cons_SELINUXTYPE_value}
    else
        log_warn "$(get_current_host_info)_[${cons_SELINUXTYPE_key}] value has been configured." false
    fi
}

# 关闭selinux结果打印输出
function close_selinux_result() {
    echo -e ""
    echo -e "\033[33m==================[6]计算节点关闭selinux开始==============================\033[0m"
    # 调用关闭selinux方法
    close_selinux
    local return_msg=($(check_selinux))
    if [ "${return_msg[0]}" == "0" ]; then
        if [ "${return_msg[1]}" == "0" ]; then
            echo -e "\033[33m==\033[0m\033[32m  配置文件SELINUX值设置正确                            [ √ ]\033[0m          \033[33m==\033[0m"
        else
            echo -e "\033[33m==\033[0m\033[31m  配置文件SELINUX值设置错误                            [ X ]\033[0m          \033[33m==\033[0m"
        fi
        if [ "${return_msg[2]}" == "0" ]; then
            echo -e "\033[33m==\033[0m\033[32m  配置文件SELINUXTYPE值设置正确                        [ √ ]\033[0m          \033[33m==\033[0m"
        else
            echo -e "\033[33m==\033[0m\033[31m  配置文件SELINUXTYPE值设置错误                        [ X ]\033[0m          \033[33m==\033[0m"
        fi
    else
        echo -e "\033[33m==\033[0m\033[31m  配置文件[${config_file_path}]未找到                  [ X ]\033[0m          \033[33m==\033[0m"
    fi
    echo -e "\033[33m==================[6]计算节点关闭selinux结束==============================\033[0m"
}

# 脚本执行合法性检查
function required_check() {
    return 0
}

############### 主函数入口 ###############
# 参数${1}表示手动执行脚本还是自动执行脚本方式
# 参数${2}是否开启DEBUG模式
is_manual_script=${1}
is_open_debug=${2}
if [ -z "${is_manual_script}" ]; then
    is_manual_script=true
fi
if [ -z "${is_open_debug}" ]; then
    is_open_debug=false
fi
manual_script_action ${is_manual_script} ${is_open_debug} required_check check_selinux_result close_selinux_result
