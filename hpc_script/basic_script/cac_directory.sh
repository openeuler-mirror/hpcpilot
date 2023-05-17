#
# Copyright (c) Huawei Technologies Co., Ltd. 2022-2022. All rights reserved.
#

#!/usr/bin/env bash
######################################################################
# 脚本描述：创建业务目录自动化脚本                                          #
# 注意事项：只在挂载了共享目录的运维节点创建                                  #
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

# 业务目录根目录
cons_root_dir=$(get_ini_value basic_conf basic_shared_directory /share)
# 业务目录二级目录
cons_second_dir=/software
# 业务目录三级目录(数组形式)
cons_third_dir=(/apps /compilers /libs /modules /mpi /tools /sourcecode)

# 直接创建目录（如果目录不存在）
# 调用方式：函数名
# 调用举例：`create_directory`
function create_directory() {
    # 创建三级目录
    for third_dir in "${cons_third_dir[@]}"; do
        if [ ! -d "${cons_root_dir}${cons_second_dir}${third_dir}" ]; then
            mkdir -m 755 -p ${cons_root_dir}${cons_second_dir}${third_dir}
        fi
    done
    log_info "Service business planning directories has been created." false
}

# 检查目录是否创建完整，给外部提供方法
# 调用方式：函数名 是否创建（默认false不创建）
# 调用举例：`check_directory` false
function check_directory() {
    # 定义返回结果
    local ret_code="0"
    local ret_message=""
    # 检查三级目录
    for third_dir in "${cons_third_dir[@]}"; do
        if [ ! -d "${cons_root_dir}${cons_second_dir}${third_dir}" ]; then
            ret_code="1"
            if [ -z "${ret_message}" ]; then
                ret_message="${cons_root_dir}${cons_second_dir}${third_dir}"
            else
                ret_message="${ret_message}\n${cons_root_dir}${cons_second_dir}${third_dir}"
            fi
            log_error "${cons_root_dir}${cons_second_dir}${third_dir} directory does not exist." false
        fi
    done
    # 根据条件是否创建目录
    if [[ -n "${1}" && "${1}" == "true" ]]; then
        create_directory
    else
        ret_info=(${ret_code} ${ret_message})
        echo ${ret_info[@]}
    fi
}

# 树形方式展示目录列表
function show_tree_directory() {
    if [ "$(rpm -qa tree)" == "" ]; then
        # 进行安装依赖
        yum install -y tree >> ${operation_log_path}/access_all.log 2>&1
        if [ "$?" == "1" ]; then
            log_warn "Tree dependency package is not found or fails to be installed." false
            return
        fi
    fi
    tree ${cons_root_dir} -d -L 2
}

function check_directory_result() {
    echo -e ""
    echo -e "\033[33m==================[3]业务规划目录创建检查结果=============================\033[0m"
    if [ -z "$(echo "$(get_current_host_ip)" | grep "${om_machine_ip}")" ]; then
        echo -e "\033[33m==\033[0m\033[32m  非运维节点无需检查                                   [ √ ]\033[0m          \033[33m==\033[0m"
    else
        local return_msg=($(check_directory false))
        if [ "${return_msg[0]}" == "0" ]; then
            echo -e "\033[33m==\033[0m\033[32m  业务规划目录创建检查结果正常                         [ √ ]\033[0m          \033[33m==\033[0m"
        else
            echo -e "\033[33m==\033[0m\033[31m  业务规划目录创建检查结果异常                         [ X ]\033[0m          \033[33m==\033[0m"
        fi
        if [ -d "${cons_root_dir}" ]; then
            echo -e "\033[33m==\033[0m\033[32m  业务规划目录如下所示：\033[0m                                              \033[33m==\033[0m"
            echo -e "\033[32m$(show_tree_directory)\033[0m"  
        fi  
    fi
    echo -e "\033[33m==================[3]业务规划目录创建检查结果=============================\033[0m"
}

function create_directory_result() {
    if [ -z "$(echo "$(get_current_host_ip)" | grep "${om_machine_ip}")" ]; then
        log_info "Do not need to create shared directories for NON-O&M node." true
        return
    fi
    # 创建目录
    create_directory
    # 检查创建结果
    check_directory_result
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
manual_script_action ${is_manual_script} ${is_open_debug} required_check check_directory_result create_directory_result ${4}
