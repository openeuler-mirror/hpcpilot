#
# Copyright (c) Huawei Technologies Co., Ltd. 2022-2022. All rights reserved.
#

#!/usr/bin/env bash
# 创建业务目录自动化脚本

# 引用公共函数文件开始
source /${3}/software/tools/hpc_script/common.sh ${3}
# 引用公共函数文件结束

# 业务目录根目录
cons_root_dir=$(get_ini_value basic_conf basic_shared_directory /share)
# 业务目录二级目录
cons_second_dir=/software
# 业务目录三级目录(数组形式)
cons_third_dir=(/apps /compilers /libs /modules /mpi /tools /sourcecode)
# 业务目录四级或者五级目录(数组形式)
cons_forth_dir=(/tools/hpc_script/basic_script /tools/hpc_script/benchmark_script /tools/hpc_script/service_script /sourcecode/ansible /sourcecode/jq)

# 直接创建目录（如果目录不存在）
# 调用方式：函数名
# 调用举例：`create_directory`
function create_directory() {
    ret_result_code=0
    # 创建三级目录
    for third_dir in "${cons_third_dir[@]}"; do
        if [ ! -d "${cons_root_dir}${cons_second_dir}${third_dir}" ]; then
            mkdir -m 755 -p ${cons_root_dir}${cons_second_dir}${third_dir}
        fi
    done
    # 创建四级目录
    for forth_dir in "${cons_forth_dir[@]}"; do
        if [ ! -d "${cons_root_dir}${cons_second_dir}${forth_dir}" ]; then
            mkdir -m 755 -p ${cons_root_dir}${cons_second_dir}${forth_dir}
        fi
    done
    log_info "$(get_current_host_info)_the service business planning directories has been created." false
    echo ${ret_result_code}
}

# 检查目录是否创建完整，给外部提供方法
# 调用方式：函数名 是否创建（默认false不创建）
# 调用举例：`check_directory` false
function check_directory() {
    # 定义返回结果
    ret_code="0"
    ret_message=""
    # 检查三级目录
    for third_dir in "${cons_third_dir[@]}"; do
        if [ ! -d "${cons_root_dir}${cons_second_dir}${third_dir}" ]; then
            ret_code="1"
            if [ -z "${ret_message}" ]; then
                ret_message="$(get_current_host_info)_${cons_root_dir}${cons_second_dir}${third_dir}"
            else
                ret_message="${ret_message}\n$(get_current_host_info)_${cons_root_dir}${cons_second_dir}${third_dir}"
            fi
            log_error "$(get_current_host_info)_${cons_root_dir}${cons_second_dir}${third_dir} directory does not exist." false
        fi
    done
    # 检查四级目录
    for forth_dir in "${cons_forth_dir[@]}"; do
        if [ ! -d "${cons_root_dir}${cons_second_dir}${forth_dir}" ]; then
            ret_code="1"
            if [ -z "${ret_message}" ]; then
                ret_message="$(get_current_host_info)_${cons_root_dir}${cons_second_dir}${forth_dir}"
            else
                ret_message="${ret_message}\n$(get_current_host_info)_${cons_root_dir}${cons_second_dir}${forth_dir}"
            fi
            log_error "$(get_current_host_info)_${cons_root_dir}${cons_second_dir}${forth_dir} directory does not exist." false
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
        yum install -y tree
        if [ "$?" == "1" ]; then
            log_warn "$(get_current_host_info)_tree dependency package is not found or fails to be installed." false
            return
        fi
    fi
    tree ${cons_root_dir} -d -L 2
}

function check_directory_result() {
    echo -e ""
    echo -e "\033[33m==================[3]计算节点目录规划检查结果=============================\033[0m"
    local return_msg=($(check_directory false))
    if [ "${return_msg[0]}" == "0" ]; then
        echo -e "\033[33m==\033[0m\033[32m  计算节点目录规划检查结果正常                         [ √ ]\033[0m          \033[33m==\033[0m"
    else
        echo -e "\033[33m==\033[0m\033[31m  计算节点目录规划检查结果异常                         [ X ]\033[0m          \033[33m==\033[0m"
    fi
    echo -e "\033[33m==\033[0m\033[32m  业务规划目录如下所示：\033[0m                                              \033[33m==\033[0m"
    echo -e "\033[32m$(show_tree_directory)\033[0m"
    echo -e "\033[33m==================[3]计算节点目录规划检查结果=============================\033[0m"
}

function create_directory_result() {
    echo -e ""
    echo -e "\033[33m=========================[3]创建业务规划目录开始==========================\033[0m"
    return_msg=($(create_directory))
    if [[ "${return_msg[0]}" == 0 ]]; then
        echo -e "\033[33m==\033[0m\033[32m  业务规划目录创建成功                                 [ √ ]\033[33m          ==\033[0m"
    else
        echo -e "\033[33m==\033[0m\033[31m  业务规划目录创建失败                                 [ X ]\033[33m          ==\033[0m"
    fi
    echo -e "\033[33m==\033[0m\033[32m  业务规划目录如下所示：\033[0m                                              \033[33m==\033[0m"
    echo -e "\033[32m$(show_tree_directory)\033[0m"
    echo -e "\033[33m=========================[3]创建业务规划目录结束==========================\033[0m"
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
manual_script_action ${is_manual_script} ${is_open_debug} required_check check_directory_result create_directory_result
