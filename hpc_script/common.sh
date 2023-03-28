#
# Copyright (c) Huawei Technologies Co., Ltd. 2022-2022. All rights reserved.
#

#!/usr/bin/env bash
# HPC自动化脚本安装公共方法脚本
# set -x

# 定义全局操作日志存放路径
global_operation_log_path=/var/log/hpctools

# 去掉首尾空格
function trim() {
    $(eval echo ${1})
}

# 去掉所有空格
function all_trim() {
    str_all_trim=$(echo ${1} | sed 's/[[:space:]]//g')
    echo ${str_all_trim}
}

# 获取当前脚本的根目录（share or workspace）
function get_root_dir() {
    # 获取当前脚本路径
    current_dir=$(cd "$(dirname $0)";pwd)
    # 截取开始的“/”
    current_dir1=${current_dir#*/}
    echo ${current_dir1%%/*}
}
root_dir=""
if [ -z "${1}" ]; then
    root_dir=$(echo "$(pwd)" | awk '{split($1,arr,"/");print arr[2]}')
else
    root_dir=${1}
fi
# ====================*.ini文件操作处理开始====================
# 操作文件
ini_file=/${root_dir}/software/tools/hpc_script/setting.ini

# 获取配置文件指定section指定key的vaLue
# 调用方式：函数名 section名称 属性key名称 默认值
# 调用举例：`get_ini_value` common_basic_conf common_date_format_001 default_value
function get_ini_value() {
    ini_section=${1}
    ini_key=${2}
    # 简单的参数合法性校验
    if [[ -z ${ini_section} || -z ${ini_key} ]]; then
        echo "please input valid parameters."
    fi
    int_value=$(awk -F " = " '/\['${ini_section}'\]/{a=1} a==1&&$1~/'${ini_key}'/ {print $2;exit}' ${ini_file} | sed -e 's/\r//g')

    # 去掉所有空格后检查是否为空（长度为0）
    str_trim=$(echo ${int_value} | sed 's/[[:space:]]//g')
    if [[ ${#str_trim} == 0 ]]; then
        # 返回给定的默认值
        echo ${3}
    else
        echo ${int_value}
    fi
}

# ====================*.ini文件操作处理结束====================

# 以JSON字符串的方式获取操作系统信息
function os_info() {
    echo "{"
    strList=''
    if [[ -e /etc/os-release ]]; then
        source /etc/os-release
        strList=${strList}"\"ID\": \"$ID\","
        strList=${strList}"\"VERSION_ID\": \"$VERSION_ID\","
        strList=${strList}"\"NAME\": \"$NAME\","
        strList=${strList}"\"VERSION\": \"$VERSION\","
        strList=${strList}"\"PRETTY_NAME\": \"$PRETTY_NAME\","
    fi

    kernel_name=$(uname -s)
    kernel_vers=$(uname -v)
    kernel_real=$(uname -r)
    kernel_arch=$(uname -p)
    kernel_os=$(uname -o)
    strList=${strList}"\"kernel_name\": \"$kernel_name\","
    strList=${strList}"\"kernel_ver\": \"$kernel_vers\","
    strList=${strList}"\"kernel_rel\": \"$kernel_real\","
    strList=${strList}"\"kernel_arch\": \"$kernel_arch\","
    strList=${strList}"\"kernel_os\": \"$kernel_os\","

    var=${strList%??}
    echo ${var}
    echo "}"
}

# 获取操作系统版本号（暂时未用）
function os_version_id01() {
    uname -a | awk -F" u|c|C|-"'{print $2}'
}

# 获取操作系统版本号
function os_version_id() {
    if [[ -e /etc/os-release ]]; then
        source /etc/os-release
        echo $VERSION_ID
    fi
}

# 获取操作系统名称。例如：CentOS、openEuler、Kylin
function os_current_name() {
    local current_os_info=($(cat /etc/system-release))
    echo ${current_os_info[0]}
}

############### 日志打印公共函数 ###############

# 日志级别 debug=1 info=2 warn=3 error=4 always=5
LOG_LEVEL=1
# 当前操作用户
CURRENT_USER=$(whoami)
# 当前执行的文件名称 ${${0}##*/}
FILE_NAME=${0}
# 当前执行的函数名称
# TODO 后续处理获取函数名称问题,目前暂时屏蔽
# FUN_NAME=${FUNCNAME[@]}
# 日志前缀
LOG_PRE_NAME=$(date "$(get_ini_value common_global_conf common_date_format_001)")_${CURRENT_USER}_${FILE_NAME##*/}


# 检查并创建运行日志存放目录
if [ ! -d "${global_operation_log_path}/" ]; then
    mkdir -m 755 -p ${global_operation_log_path}/
fi

# 调试日志
# 调用方式：函数名 调试信息 是否打印到屏幕(值为true或false),无参数默认是打印到屏幕
# 调用举例：`log_debug` "debug information" true
function log_debug() {
    local is_print_screen=$(all_trim ${2})
    if [ -z "${is_print_screen}" ]; then
        is_print_screen=true
    fi

    if [ "${is_print_screen}" == "true" ]; then
        [ ${LOG_LEVEL} -le 1 ] && echo -e "\033[34m[DEBUG]" ${LOG_PRE_NAME} ${1}"\033[0m"
    else
        [ ${LOG_LEVEL} -le 1 ] && echo -e "\033[34m[DEBUG]" ${LOG_PRE_NAME} ${1}"\033[0m" >/dev/null
    fi
    [ ${LOG_LEVEL} -le 1 ] && echo -e "[DEBUG] ${LOG_PRE_NAME} ${1}" >>${global_operation_log_path}/access_all.log
}
# 信息日志
# 调用方式：函数名 打印信息 是否打印到屏幕(值为true或false),无参数默认是打印到屏幕
# 调用举例：`log_info` "information" true
function log_info() {
    local is_print_screen=$(all_trim ${2})
    if [ -z "${is_print_screen}" ]; then
        is_print_screen=true
    fi

    if [ "${is_print_screen}" == "true" ]; then
        [ ${LOG_LEVEL} -le 2 ] && echo -e "\033[32m[INFO]" ${LOG_PRE_NAME} ${1}"\033[0m"
    else
        [ ${LOG_LEVEL} -le 2 ] && echo -e "\033[32m[INFO]" ${LOG_PRE_NAME} ${1}"\033[0m" >/dev/null
    fi
    [ ${LOG_LEVEL} -le 2 ] && echo -e "[INFO] ${LOG_PRE_NAME} ${1}" >>${global_operation_log_path}/access_all.log
}
# 警告日志
# 调用方式：函数名 警告信息 是否打印到屏幕(值为true或false),无参数默认是打印到屏幕
# 调用举例：`log_warn` "warn information" true
function log_warn() {
    local is_print_screen=$(all_trim ${2})
    if [ -z "${is_print_screen}" ]; then
        is_print_screen=true
    fi

    if [ "${is_print_screen}" == "true" ]; then
        [ ${LOG_LEVEL} -le 3 ] && echo -e "\033[33m[WARN]" ${LOG_PRE_NAME} ${1}"\033[0m"
    else
        [ ${LOG_LEVEL} -le 3 ] && echo -e "\033[33m[WARN]" ${LOG_PRE_NAME} ${1}"\033[0m" >/dev/null
    fi
    [ ${LOG_LEVEL} -le 3 ] && echo -e "[WARN] ${LOG_PRE_NAME} ${1}" >>${global_operation_log_path}/access_all.log
}
# 错误日志
# 调用方式：函数名 错误信息 是否打印到屏幕(值为true或false),无参数默认是打印到屏幕
# 调用举例：`log_error` "error information" true
function log_error() {
    local is_print_screen=$(all_trim ${2})
    if [ -z "${is_print_screen}" ]; then
        is_print_screen=true
    fi

    if [ "${is_print_screen}" == "true" ]; then
        [ ${LOG_LEVEL} -le 4 ] && echo -e "\033[31m[ERROR]" ${LOG_PRE_NAME} ${1}"\033[0m"
    else
        [ ${LOG_LEVEL} -le 4 ] && echo -e "\033[31m[ERROR]" ${LOG_PRE_NAME} ${1}"\033[0m" >/dev/null
    fi
    [ ${LOG_LEVEL} -le 4 ] && echo -e "[ERROR] ${LOG_PRE_NAME} ${1}" >>${global_operation_log_path}/access_all.log
    [ ${LOG_LEVEL} -le 4 ] && echo -e "[ERROR] ${LOG_PRE_NAME} ${1}" >>${global_operation_log_path}/access_error.log
}
# 一直都会打印的日志
# 调用方式：函数名 打印信息 是否打印到屏幕(值为true或false),无参数默认是打印到屏幕
# 调用举例：`log_always` "print information" true
function log_always() {
    local is_print_screen=$(all_trim ${2})
    if [ -z "${is_print_screen}" ]; then
        is_print_screen=true
    fi

    if [ "${is_print_screen}" == "true" ]; then
        [ ${LOG_LEVEL} -le 5 ] && echo -e "[ALWAYS] ${LOG_PRE_NAME} ${1}"
    else
        [ ${LOG_LEVEL} -le 5 ] && echo -e "[ALWAYS] ${LOG_PRE_NAME} ${1}" >/dev/null
    fi
    [ ${LOG_LEVEL} -le 5 ] && echo -e "\033[32m[ALWAYS]" ${LOG_PRE_NAME} ${1}"\033[0m" >>${global_operation_log_path}/access_all.log
}

# 一直都会打印的日志
# 调用方式：函数名
# 调用举例：`view_log_path`
function view_log_path() {
    echo -e ""
    echo -e "\033[33m##########################################################################\033[0m"
    echo -e "\033[33m##\033[0m                                                                      \033[33m##\033[0m"
    echo -e "\033[33m##\033[0m\033[32m  运行日志：${global_operation_log_path}/access_all.log                          \033[33m##\033[0m"
    echo -e "\033[33m##\033[0m\033[32m  错误日志：${global_operation_log_path}/access_error.log                        \033[33m##\033[0m"
    echo -e "\033[33m##\033[0m                                                                      \033[33m##\033[0m"
    echo -e "\033[33m##########################################################################\033[0m"
    echo -e ""
}

# 获取类properties文件中key对应的value
# 调用方式：函数名 文件路径 属性key
# 调用举例：`get_property_value` /etc/selinux/config SELINUX

function get_property_value() {
    result=""
    filePath="${1}" #待读取文件路径
    key="${2}"      #关键字key
    if [[ -z "${key}" || -z "${filePath}" ]]; then
        echo "参数错误，未能指定有效Key。"
        echo "" >&2
        exit 1
    fi

    if [ ! -f ${filePath} ]; then
        echo "属性文件（${filePath}） 不存在。"
        echo "" >&2
        exit 1
    fi

    if [ ! -r ${filePath} ]; then
        echo "当前用户不具有对属性文件（${filePath}）的可读权限。"
        echo "" >&2
        exit 1
    fi

    keyLength=$(echo ${key} | wc -L)
    lineNumStr=$(cat ${filePath} | wc -l)
    lineNum=$((${lineNumStr}))
    for ((i = 1; i <= ${lineNum}; i++)); do
        oneLine=$(sed -n ${i}p ${filePath})
        if [ "${oneLine:0:((keyLength))}" = "${key}" ] && [ "${oneLine:$((keyLength)):1}" = "=" ]; then
            result=${oneLine#*=}
            break
        fi
    done
    echo ${result}
}

# 修改类properties文件中key对应的value
# 调用方式：函数名 文件路径 属性key 属性value
# 调用举例：`modify_property_value` /etc/selinux/config SELINUX disabled
function modify_property_value() {
    filePath="${1}" #待读取文件路径
    key="${2}"      #关键字key
    value="${3}"    #修改替换的新值
    sed -i "s/${key}=.*/${key}=${value}/" ${filePath}
}

# 去掉匹配行行首字符(#)
# 调用方式：函数名 文件路径 查找的字符
# 调用举例：`remove_match_line_symbol` /etc/selinux/config SELINUX
function remove_match_line_symbol() {
    local filePath="${1}" # 待读取文件路径
    local key="${2}"      # 关键字key
    # 去掉匹配行的首字符
    sed -i "/${key}/ s/^#//" ${filePath}
}

# 获取当前主机的IP地址
# 调用方式：函数名
# 调用举例：`get_current_host_ip`
function get_current_host_ip() {
    if [ "$(rpm -qa net-tools)" == "" ]; then
        yum install -y net-tools &>/dev/null
    fi
    ip_addr=$(ifconfig -a | grep inet | grep -v 127.0.0.1 | grep -v inet6 | awk '{print $2}' | tr -d "addrs")
    echo ${ip_addr}
}

# 获取当前主机的主机名称hostname
# 调用方式：函数名
# 调用举例：`get_current_host_name`
function get_current_host_name() {
    host_name=$(cat /etc/hostname)
    echo ${host_name}
}

# 从hostname.csv文件中获取当前主机的主机业务分组名称
# 调用方式：函数名
# 调用举例：`get_current_host_group`
function get_current_host_group() {
    local group_name="未知分组"
    # hostname.csv配置文件路径
    local hostname_file=$(get_ini_value basic_conf basic_shared_directory /share)/software/tools/hpc_script/hostname.csv
    if [ $(is_file_exist ${hostname_file}) = 0 ]; then
        # tail -n +2 从第二行开始读取数据，第一行为标题行
        for line in $(cat ${hostname_file} | tail -n +2); do
            # 检查判断字符串长度是否为0
            if [ -n "${line}" ]; then
                local ip_addr=$(echo ${line} | awk -F "," '{print $1}')
                if [[ -n "${ip_addr}" && "${ip_addr}" == "$(get_current_host_ip)" ]]; then
                    group_name=$(echo ${line} | awk -F "," '{print $3}')
                    break
                fi
            fi
        done
    else
        log_error "$(get_current_host_info)_${cons_hostname_file} file doesn't exist." false
    fi
    echo ${group_name}
}

# 获取当前主机的主机名称hostname和IP地址，主要用于输出打印信息
# 调用方式：函数名
# 调用举例：`get_current_host_info`
function get_current_host_info() {
    echo "[$(get_current_host_ip)_$(get_current_host_name)]"
}

# 检查服务是否安装并启动
# 调用方式：函数名 服务名称
# 调用举例：`service_is_setup_and_start` 服务名称
function service_is_setup_and_start() {
    # 待检查的服务名称
    service=${1}
    # 返回标识符
    cons_ret_flag="0"
    netstat -anp | grep ${service} &>/dev/null
    if [ $? -eq 0 ]; then
        log_info "${service} the service has been started."
        echo ${cons_ret_flag}
    else
        rpm -q ${service} &>/dev/null
        if [ $? -eq 0 ]; then
            log_info "${service} service installed, starting..."
            service ${service} start
            echo ${cons_ret_flag}
        else
            # log_warn "${service} the service is not installed."
            echo 1
        fi
    fi
}

# 检查判断文件是否存在
# 调用方式：函数名 文件路径全名称
# 调用举例：`is_file_exist` /workspace/software/scripts/properties/xxx.txt
function is_file_exist() {
    if [ -f ${1} ]; then
        echo 0
    else
        echo 1
    fi
}

# 检查当前服务器是否联网（可访问外网）
# 调用方式：函数名
# 调用举例：`is_connect_network`
function is_connect_network() {
    # 设置超时时间
    local timeout=3
    # 测试目标网站
    local target=www.baidu.com
    #获取响应状态码
    local ret_code=$(curl -I -s --connect-timeout ${timeout} ${target} -w %{http_code} | tail -n1)
    if [ "x${ret_code}" = "x200" ]; then
        # 网络畅通
        return 1
    else
        # 网络不畅通
        return 0
    fi
    return 0
}

# 检查当前机器是物理机还是虚拟机
# 调用方式：函数名
# 返回值：0代表物理机，1代表虚拟机
# 调用举例：`is_physical_machine`
function is_physical_machine() {
    if [[ "$(dmidecode -s system-product-name)" =~ "Virtual" ]] ; then
        echo 1
    else
        echo 0
    fi
}

# 检查当前机器是否支持GPU
# 调用方式：函数名
# 返回值：0支持，1不支持
# 调用举例：`is_gpu_machine`
function is_gpu_machine() {
    local result=$(lspci | grep -i nvidia)
    if [ -z "${result}" ]; then
        echo 1
    else
        echo 0
    fi
}

# 检查当前机器是否是运维节点
# 调用方式：函数名
# 返回值：0是运维节点，1非运维节点
# 调用举例：`is_om_machine`
function is_om_machine() {
    if [ "$(get_current_host_ip)" == "$(get_ini_value basic_conf basic_om_master_ip)" ]; then
        echo 0
    else
        echo 1
    fi
}

# 检查执行的命令是否存在
# 调用方式：函数名 待执行命令
# 返回值：0不存在，1代表存在
# 调用举例：`is_command_exist` tar
function is_command_exist() {
    local ret='0'
    command -v ${1} >/dev/null 2>&1 || { local ret='1'; }
    if [ "${ret}" = "0" ]; then
        echo 1
    else
        echo 0  
    fi
}

# 手动单个脚本执行交互方法
# 调用方式：函数名 是否手动（true/false） 是否开启DEBUG（true/false）
# 返回值：check或者config or install
# 调用举例：`manual_script_action` true false
function manual_script_action() {
    if [ -n "${3}" ]; then
        # 执行脚本合法性检查方法
        ${3}
        if [ "$?" == "1" ]; then
            exit 1
        fi
    fi
    # 是否开启DEBUG
    local is_open_debug=${2}
    if [ -n "${is_open_debug}" ] && [ "${is_open_debug}" == "true" ]; then
        set -x
    fi
    # 是否是自动化执行脚本
    # 自动化脚本不在命令行打印日志，只输出到文件中。
    local is_manual_script=${1}
    # 判断输入参数的合法性
    if [ -z "${is_manual_script}" ]; then
        is_manual_script=true
    fi
    if [ "${is_manual_script}" == "false" ]; then
         return
    fi
    if [ "${is_manual_script}" != "true" ]; then
         echo -e "\033[31m please input a valid parameter <true>. example: *.sh true\033[0m"
         return
    fi
    
    # 手动选择需要执行的方法
    echo -e "\033[32m please select the method to execute.\033[0m"
    select action_var in "check" "config or install" "system exit"; do
        if [ "${action_var}" == "check" ]; then
            ${4}
        elif [ "${action_var}" == "config or install" ]; then
            ${5}
        elif [ "${action_var}" == "system exit" ]; then
            exit 0
        else 
            echo -e "\033[31m selected drop-down list does not match the defined, please select again.\033[0m"
        fi
    done
}

# 检查某个目录下文件是否存在某个文件
# 判断依据是如果文件名包含关键字且后缀名为指定的后缀名即为当前需要查找的文件
# 或者文件名以关键字_操作系统英文名称开头的文件即为当前需要需要查找的文件
# 操作系统前缀名称，比如：CentOS、openEuler、Kylin

# 调用方式：函数名 文件所在路径 文件关键字key 文件后缀名
# 返回值：""不存在，否则返回文件名
# 调用举例：`find_file_by_path` /workspace/software/libs cuda run
function find_file_by_path() {
    query_file_name=""
    # 当前操作系统名称
    local current_os_info=($(cat /etc/system-release))
    cd ${1}
    local files=$(ls ${1})
    if [ -n "${files}" ]; then
        for file_name in ${files}; do
            # 判断字符串是否以XXX字符串开头
            if [[ "${file_name}" =~ ^"${2}_${current_os_info[0]}"* ]]; then
                query_file_name=${file_name}
                break
            fi
            if [[ "${file_name}" =~ "${2}" ]] && [ "${file_name##*.}" == "${3}" ]; then
                query_file_name=${file_name}
                break
            fi
        done
    else
        log_error "$(get_current_host_info)_[${1}] directory is empty." false
    fi
    echo ${query_file_name}
}

# 删除指定文件所有空白行
# 调用方式：函数名 指定文件全路径
# 返回值：无
# 调用举例：`remove_all_blank_line` /etc/fstab
function remove_all_blank_line() {
    if [ -n "${1}" ]; then
        sed -i /^[[:space:]]*$/d ${1}
    else
        log_error "$(get_current_host_info)_input parameter is blank." false
    fi
}

# 获取基础配置所需安装依赖软件包所在文件夹
# 调用方式：函数名
# 返回值：文件夹路径
# 调用举例：`get_sourcecode_dir`
function get_sourcecode_dir() {
    echo $(get_ini_value basic_conf basic_shared_directory /share)/software/sourcecode
}