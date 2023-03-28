#
# Copyright (c) Huawei Technologies Co., Ltd. 2022-2022. All rights reserved.
#

#!/usr/bin/env bash
# 配置最大进程数自动化脚本

# 引用公共函数文件开始
source /${3}/software/tools/hpc_script/common.sh ${3}
# 引用公共函数文件结束

# hostname.csv配置文件路径
hostname_file=$(get_ini_value basic_conf basic_shared_directory /share)/software/tools/hpc_script/hostname.csv
# 配置文件路径
cons_ulimit_dir_path="/etc/security/limits.d"
# 警告提示信息
cons_warn_msg="the configuration content already exists and does not need to be modified."

cons_nproc_conf="*          soft    nproc     unlimited\nroot       soft    nproc     unlimited"
cons_limits_conf="* soft memlock unlimited\n* hard memlock unlimited\n* soft nofile 1000000\n* hard nofile 1000000\n* hard nproc 1000000\n* soft nproc 1000000"
# 当前主机IP地址
current_ip_addr=$(get_current_host_ip)

# 从hostname。csv文件中检查判断当前主机是否在ccs+ccp分组下
function find_ccs_ccp() {
    # 是否找到 1=未找到，0=找到
    local is_found="1"
    if [ "$(is_file_exist ${hostname_file})" == "0" ]; then
        # tail -n +2 从第二行开始读取数据，第一行为标题行
        for line in $(cat ${hostname_file} | tail -n +2); do
            # 检查判断字符串长度是否为0
            if [ -n "${line}" ]; then
                local group_name=$(echo ${line} | awk -F "," '{print $3}')
                if [ -n "${group_name}" ]; then
                    if [[ "${group_name}" =~ "ccsccp" && "${current_ip_addr}" == "$(echo ${line} | awk -F "," '{print $1}')"  ]]; then
                        is_found="0"
                        break
                    fi
                fi
            fi
        done
    else
        log_error "$(get_current_host_info)_${hostname_file} file doesn't exist." false
    fi
    echo ${is_found}
}

# 检查ulimit配置是否正常
function check_ulimit() {
    # ret_conf_code值为0代表已配置 1代表未配置 2代表当前节点非[CCS+CCP]无需配置
    local ret_conf_code="0"
    if [ "$(find_ccs_ccp)" == "0" ]; then
        if [ "$(is_file_exist "${cons_ulimit_dir_path}/20-nproc.conf")" == "0" ]; then
            local result=$(cat ${cons_ulimit_dir_path}/20-nproc.conf | grep "*          soft    nproc     unlimited")
            if [ "${result}" == "" ]; then
                ret_conf_code="1"
            fi
        else
            local result1=$(cat /etc/security/limits.conf | grep "* hard nofile 1000000")
            if [ "${result1}" == "" ]; then
                ret_conf_code="1"
            fi
        fi
    else
        ret_conf_code="2"
    fi
    echo ${ret_conf_code}
}

# 检查ulimit配置是否正常结果打印输出
function check_ulimit_result() {
    echo -e ""
    echo -e "\033[33m==================[11]计算节点ulimit配置检查==============================\033[0m"
    local return_msg=($(check_ulimit))
    if [ "${return_msg[0]}" == "0" ]; then
        echo -e "\033[33m==\033[0m\033[32m  计算节点ulimit配置检查正常                           [ √ ]\033[0m          \033[33m==\033[0m"
    elif [ "${return_msg[0]}" == "1" ]; then
        echo -e "\033[33m==\033[0m\033[31m  计算节点ulimit未配置                                 [ X ]\033[0m          \033[33m==\033[0m"
    else
        echo -e "\033[33m==\033[0m\033[32m  当前计算节点非[CCS+CCP]分组无需配置                  [ √ ]\033[0m          \033[33m==\033[0m"
    fi
    echo -e "\033[33m==================[11]计算节点ulimit配置检查==============================\033[0m"
}

# 配置操作系统ulimit
function config_ulimit () {
    if [ "$(find_ccs_ccp)" == "0" ]; then
        if [ "$(is_file_exist "${cons_ulimit_dir_path}/20-nproc.conf")" == "0" ]; then
            # 判断是否进行文件修改
            if [ -n "$(cat ${cons_ulimit_dir_path}/20-nproc.conf | grep "*          soft    nproc     unlimited")" ]; then
                log_warn $(get_current_host_info)_${cons_warn_msg} false
            else
                # 修改配置文件
                # TODO 当前采用覆盖的形式不知是否正确，后续需要讨论_20230116
                echo -ne "${cons_nproc_conf}" > ${cons_ulimit_dir_path}/20-nproc.conf
            fi
        else
            if [ -n "$(cat /etc/security/limits.conf | grep "* hard nofile 1000000")" ]; then
                log_warn $(get_current_host_info)_${cons_warn_msg} false
            else
                # 追加内容到配置文件中
                echo -ne "${cons_limits_conf}" >> /etc/security/limits.conf
            fi
        fi
    else
        log_info "$(get_current_host_info)_当前计算节点非[CCS+CCP]分组无需配置" false
    fi
}

function config_ulimit_result() {
    echo -e ""
    echo -e "\033[33m==================[11]计算节点ulimit配置开启==============================\033[0m"
    # 调用配置操作系统ulimit方法
    config_ulimit
    # 检查配置是否OK
    local return_msg=($(check_ulimit))
    if [ "${return_msg[0]}" == "0" ]; then
        echo -e "\033[33m==\033[0m\033[32m  计算节点ulimit配置检查正常                           [ √ ]\033[0m          \033[33m==\033[0m"
    elif [ "${return_msg[0]}" == "1" ]; then
        echo -e "\033[33m==\033[0m\033[31m  计算节点ulimit未配置                                 [ X ]\033[0m          \033[33m==\033[0m"
    else
        echo -e "\033[33m==\033[0m\033[32m  当前计算节点非[CCS+CCP]分组无需配置                  [ √ ]\033[0m          \033[33m==\033[0m"
    fi
    echo -e "\033[33m==================[11]计算节点ulimit配置结束==============================\033[0m"
}

# 脚本执行合法性检查
function required_check() {
    if [ $(is_file_exist ${hostname_file}) == "1" ]; then
        echo -e "\033[31m [${hostname_file}] file does not exist, system exit.\033[0m"
        return 1
    fi
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
manual_script_action ${is_manual_script} ${is_open_debug} required_check check_ulimit_result config_ulimit_result