#
# Copyright (c) Huawei Technologies Co., Ltd. 2022-2022. All rights reserved.
#

#!/usr/bin/env bash
# 批量配置网络（IB/RoCE）,网卡IB模式切换为RoCE模式自动化脚本

# 引用公共函数文件开始
source /${3}/software/tools/hpc_script/common.sh ${3}
# 引用公共函数文件结束

# 检查是否已切换到RoCE网卡
function check_config() {
    local ret_edit_code=0
    # 检查判断是否是物理机
    if [ "$(is_physical_machine)" == "1" ]; then
        log_info "$(get_current_host_info)_is a virtual machine, do not need to configure the network adapter." false
        ret_edit_code=3
    else
        # 1. 检查是否安装mellanox网卡驱动
        if [ -z "$(lspci | grep Mell)" ] || [ "$(is_command_exist "mlxconfig")" == "0" ]; then
            log_info "$(get_current_host_info)_is not installed mellanox driver or installation failed." false
            ret_edit_code=2
        else
            # 获取设备名称
            local device=$(mlxconfig q|grep 'Device:'|awk '{print $2}')
            # 查看当前网卡模式
            local driver_type=$(mlxconfig -d ${device} q | grep LINK_TYPE | awk '{print $2}')
            if [ "${driver_type}" == "IB(1)" ]; then
                log_info "$(get_current_host_info)_the current driver mode is IB." false
                ret_edit_code=1
            else
                log_info "$(get_current_host_info)_the current driver mode is RoCE." false
                ret_edit_code=0
            fi
        fi
    fi
    ret_info=(${ret_edit_code})
    echo ${ret_info[@]}
}

function check_config_result() {
    echo -e ""
    echo -e "\033[33m==================[10]计算节点网络配置检查结果============================\033[0m"
    local return_msg=($(check_config))
    if [ "${return_msg[0]}" == "3" ]; then
        echo -e "\033[33m==\033[0m\033[32m  当前计算节点为虚拟机无需切换网卡驱动                 [ √ ]\033[0m          \033[33m==\033[0m"
    elif [ "${return_msg[0]}" == "0" ]; then
        echo -e "\033[33m==\033[0m\033[32m  当前计算节点网卡模式为RoCE                           [ √ ]\033[0m          \033[33m==\033[0m"
    elif [ "${return_msg[0]}" == "1" ]; then
        echo -e "\033[33m==\033[0m\033[31m  当前计算节点网卡模式为IB                             [ X ]\033[0m          \033[33m==\033[0m"
    else
        echo -e "\033[33m==\033[0m\033[31m  当前计算节点未安装mellanox driver网卡驱动            [ X ]\033[0m          \033[33m==\033[0m"
    fi
    echo -e "\033[33m==================[10]计算节点网络配置检查结果============================\033[0m"
}

# 编辑配置网卡IB模式切换为RoCE模式
function edit_config() {
    local check_result=$(check_config)
    local ret_code=3
    if [ "${check_result}" == "1" ]; then
        ############### 切换网络IB模式为RoCE模式 ###############
        # 1. 启动网卡
        mst start
        # 2. 获取设备名称
        local device=$(mlxconfig q|grep 'Device:'|awk '{print $2}')
        # 3. 切换网卡模式
        mlxconfig -y -d ${device} s LINK_TYPE_P1=2
        # 4. 验证切换是否成功
        local driver_type=$(mlxconfig -d ${device} q | grep LINK_TYPE | awk '{print $2}')
        if [ "${driver_type}" == "IB(1)" ]; then
            log_info "$(get_current_host_info)_the current driver mode failed to switch." false
            ret_code=1
        else
            log_info "$(get_current_host_info)_the current driver mode success to switch." false
            ret_code=0
        fi
    else
        ret_code=0
    fi
    echo ${ret_code}
}

function edit_config_result() {
    echo -e ""
    echo -e "\033[33m====================[10]计算节点网络配置开始==============================\033[0m"
    local return_msg=$(edit_config)
    if [ "${return_msg}" == "3" ]; then
        echo -e "\033[33m==\033[0m\033[32m  当前计算节点为虚拟机无需切换网卡驱动                 [ √ ]\033[0m          \033[33m==\033[0m"
    elif [ "${return_msg}" == "0" ]; then
        echo -e "\033[33m==\033[0m\033[32m  当前计算节点网卡已切换RoCE                           [ √ ]\033[0m          \033[33m==\033[0m"
    elif [ "${return_msg}" == "1" ]; then
        echo -e "\033[33m==\033[0m\033[31m  当前计算节点网卡切换RoCE失败                         [ X ]\033[0m          \033[33m==\033[0m"
    else
        echo -e "\033[33m==\033[0m\033[31m  当前计算节点未安装mellanox driver网卡驱动            [ X ]\033[0m          \033[33m==\033[0m"
    fi
    echo -e "\033[33m====================[10]计算节点网络配置结束==============================\033[0m"
}

# 脚本执行合法性检查
function required_check() {
    # 检查是否是物理机并且安装了mellanox驱动
    # TODO 目前关闭了检查因为需要重启后检验才有效果
#    if [ "$(is_physical_machine)" == "0" ] && [ -z "$(lspci | grep Mell)" ]; then
#        echo -e "\033[32m current machine s not installed mellanox driver, system exit.\033[0m"
#        return 0
#    fi
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
manual_script_action ${is_manual_script} ${is_open_debug} required_check check_config_result edit_config_result