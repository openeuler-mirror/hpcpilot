#
# Copyright (c) Huawei Technologies Co., Ltd. 2022-2022. All rights reserved.
#

#!/usr/bin/env bash
######################################################################
# 脚本描述：批量设置主机名自动化脚本                                         #
# 注意事项：无                                                          #
######################################################################
# set -x

# 引用公共函数文件开始
if [ "${3}" == "opt" ]; then
    # 定义脚本文件、配置文件存放目录
    base_directory=/${3}/hpcpilot/hpc_script
    # 依赖软件存放路径[/opt/hpcpilot/sourcecode]
    sourcecode_dir=/${3}/hpcpilot/sourcecode/ansible
else
    # 定义脚本文件、配置文件存放目录
    base_directory=/${3}/software/tools/hpc_script
    sourcecode_dir=/${3}/software/sourcecode/ansible
fi
source ${base_directory}/common.sh ${3}
# 引用公共函数文件结束

# 当前主机IP地址
current_ip_addr=$(get_current_host_ip)
# 当前主机名称
current_host_name=$(get_current_host_name)

# 检查hostname已修改
function check_hostname() {
    # 0=正常返回检查OK 1=配置文件未找到无法检查 2=当前主机未设置hostname 3=配置文件中未找到当前主机
    local ret_code="0"
    # 检查文件是否存在
    if [ $(is_file_exist ${hostname_file}) == "1" ]; then
        ret_code="1"
        echo ${ret_code}
        return
    fi

    # flag用来标识是否在配置文件中找到了该节点
    local flag="0"
    # tail -n +2 从第二行开始读取数据，第一行为标题行
    for line in $(cat ${hostname_file} | tail -n +2); do
        # 检查判断字符串长度是否为0
        if [ -n "${line}" ]; then
            local file_host_ip=$(echo ${line} | awk -F "," '{print $1}')
            if [ -n "$(echo "${current_ip_addr}" | grep "${file_host_ip}")" ]; then
                flag="1"
                file_host_name=$(echo ${line} | awk -F "," '{print $2}')
                if [ "${file_host_name}" != "${current_host_name}" ]; then
                    ret_code="2"
                    break
                fi
            fi
        fi
    done

    if [ "${flag}" == "0" ]; then
        ret_code="3"
    fi
    echo ${ret_code}
}

function check_hostname_result() {
    echo -e ""
    echo -e "\033[33m==================[4]节点名称规划设置检查结果=============================\033[0m"
    local return_msg
    if [ -n "${1}" ] && [ "${1}" == "modify" ]; then
        return_msg=(0)
    else
        return_msg=($(check_hostname))
    fi
    if [ "${return_msg[0]}" == 0 ]; then
        echo -e "\033[33m==\033[0m\033[32m  计算节点名称规划检查结果正常                         [ √ ]\033[0m          \033[33m==\033[0m"
    elif [ "${return_msg[0]}" == 1 ]; then
        echo -e "\033[33m==\033[0m\033[31m  [hostname.csv]配置文件未找到无法检查                 [ X ]\033[0m          \033[33m==\033[0m"
    elif [ "${return_msg[0]}" == 2 ]; then
        echo -e "\033[33m==\033[0m\033[31m  当前计算节点hostname与配置文件中不匹配               [ X ]\033[0m          \033[33m==\033[0m"
    else
        echo -e "\033[33m==\033[0m\033[31m  当前计算节点未在配置文件中找到                       [ X ]\033[0m          \033[33m==\033[0m"
    fi
    echo -e "\033[33m==================[4]节点名称规划设置检查结果=============================\033[0m"
}

# 根据配置文件修改主机节点hostname
function modify_hostname() {
    # 检查文件是否存在
    if [ "$(is_file_exist ${hostname_file})" == "0" ]; then
        # tail -n +2 从第二行开始读取数据，第一行为标题行
        for line in $(cat ${hostname_file} | tail -n +2); do
            # 检查判断字符串长度是否为0
            if [ -n "${line}" ]; then
                local file_host_ip=$(echo ${line} | awk -F "," '{print $1}')
                if [ -n "$(echo "${current_ip_addr}" | grep "${file_host_ip}")" ]; then
                    local file_host_name=$(echo ${line} | awk -F "," '{print $2}')
                    if [ "${file_host_name}" != "${current_host_name}" ]; then
                        # 去掉最后的换行符
                        file_host_name=$(echo ${file_host_name} | tr '\n\r' ' ')
                        # 设置对应的主机名称
                        # TODO 20230222_需要对主机名称合法性校验
                        # 主机名合法性：最多为64个字符，仅可包含“.”、“_”、“-”、“a-z”、“A-Z”和“0-9”这些字符，并且不能以“.”打头和结尾，也不能两个“.”连续；
                        hostnamectl set-hostname "${file_host_name}"
                    fi
                    break
                fi
            fi
        done
    else
        log_error "[${hostname_file}] file doesn't exist." false
    fi
}

function modify_hostname_result() {
    # 修改节点hostname名称
    modify_hostname
    # 检查hostname修改结果
    check_hostname_result modify
}

# 脚本执行合法性检查
function required_check() {
    if [ $(is_file_exist ${hostname_file}) == "1" ]; then
        log_error "[${hostname_file}] file doesn't exist, please check." true
        return 1
    fi
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
manual_script_action ${is_manual_script} ${is_open_debug} required_check check_hostname_result modify_hostname_result ${4}
