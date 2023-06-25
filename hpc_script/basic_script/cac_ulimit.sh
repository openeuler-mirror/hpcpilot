#
# Copyright (c) Huawei Technologies Co., Ltd. 2022-2022. All rights reserved.
#

#!/usr/bin/env bash
######################################################################
# 脚本描述：配置最大进程数自动化脚本                                         #
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

# ulimit配置文件
ulimit_file=/etc/security/limits.conf
# ulimit配置文件内容
limits_conf_content="* soft memlock unlimited\n* hard memlock unlimited\n* soft stack unlimited\n* hard stack unlimited\n* soft nofile 1000000\n* hard nofile 1000000\n* hard nproc 1000000\n* soft nproc 1000000"

# 检查配置文件/etc/security/limits.conf配置是否正确
function check_ulimit() {
    # ret_code值为0代表配置正确 1代表配置不正确
    local ret_code=0
    local var1=$(grep "* soft memlock unlimited" ${ulimit_file})
    local var2=$(grep "* hard memlock unlimited" ${ulimit_file})
    local var3=$(grep "* soft stack unlimited" ${ulimit_file})
    local var4=$(grep "* hard stack unlimited" ${ulimit_file})
    local var5=$(grep "* soft nofile 1000000" ${ulimit_file})
    local var6=$(grep "* hard nofile 1000000" ${ulimit_file})
    local var7=$(grep "* hard nproc 1000000" ${ulimit_file})
    local var8=$(grep "* soft nproc 1000000" ${ulimit_file})
    if [ -z "${var1}" ] || [ -z "${var2}" ] || [ -z "${var3}" ] || [ -z "${var4}" ] || [ -z "${var5}" ] || [ -z "${var6}" ] || [ -z "${var7}" ] || [ -z "${var8}" ]; then
        ret_code=1
    fi
    echo ${ret_code}
}

# 检查ulimit配置是否正常结果打印输出
function check_ulimit_result() {
    echo -e ""
    echo -e "\033[33m==================[10]计算节点ulimit配置检查==============================\033[0m"
    local return_msg=($(check_ulimit))
    if [ "${return_msg[0]}" == "0" ]; then
        echo -e "\033[33m==\033[0m\033[32m  计算节点ulimit配置检查正常                           [ √ ]\033[0m          \033[33m==\033[0m"
    else
        echo -e "\033[33m==\033[0m\033[31m  计算节点ulimit未配置或配置有误                       [ X ]\033[0m          \033[33m==\033[0m"
    fi
    echo -e "\033[33m==================[10]计算节点ulimit配置检查==============================\033[0m"
}

# 配置操作系统ulimit
function config_ulimit() {
    # 检查ulimit配置文件是否存在，不存在则创建
    if [ ! -f "${ulimit_file}" ]; then
        touch ${ulimit_file}
        # 追加内容到配置文件中
        echo -ne "${limits_conf_content}" >> ${ulimit_file}
    else
        if [ "$(check_ulimit)" == "0" ]; then
            log_warn "Configuration content already exists and does not need to be modified." false
        else
            # 追加内容到配置文件中
            echo -ne "${limits_conf_content}" >> ${ulimit_file}
        fi
    fi
}

function config_ulimit_result() {
    # 调用配置操作系统ulimit方法
    config_ulimit
    # 检查配置结果并打印输出
    check_ulimit_result
}

# 脚本执行合法性检查
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
manual_script_action ${is_manual_script} ${is_open_debug} required_check check_ulimit_result config_ulimit_result ${4}