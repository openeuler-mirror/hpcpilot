#
# Copyright (c) Huawei Technologies Co., Ltd. 2022-2022. All rights reserved.
#

#!/usr/bin/env bash
######################################################################
# 脚本描述：HPCPILOT自动化脚本安装公共方法脚本(工具脚本)                       #
# 注意事项：无                                                          #
######################################################################
# set -x

# ###############增加脚本重复加载引用执行控制开始###############
_sourced_="__sourced_$$__"
if [ -z "${!_sourced_}" ]; then
    eval "${_sourced_}=1"
else
    return
fi
# ###############增加脚本重复加载引用执行控制结束###############

if [ -z "${1}" ]; then
    root_dir=$(echo "$(pwd)" | awk '{split($1,arr,"/");print arr[2]}')
else
    root_dir=${1}
fi
# operation_log_path表示全局操作日志存放路径
# ini_file表示setting.ini配置文件存放路径
if [ "${root_dir}" == "opt" ]; then
    base_directory=/${root_dir}/hpcpilot/hpc_script
    operation_log_path=/${root_dir}/hpcpilot/logs
    sourcecode_dir=/${root_dir}/hpcpilot/sourcecode
else
    base_directory=/${root_dir}/software/tools/hpc_script
    operation_log_path=/${root_dir}/software/tools/logs
    sourcecode_dir=/${root_dir}/software/sourcecode
fi
# 根据传入参数定义ANSIBLE临时日志存放路径
ansible_log_path=${operation_log_path}/ansible
# hostname.csv文件
hostname_file=${base_directory}/hostname.csv
# 配置文件setting.ini所在的目录
ini_file=${base_directory}/setting.ini
# 集成自动执行标识（默认true）
auto_run_flag=true

# 去掉首尾空格
# 调用方式：函数名
# 调用举例：`trim` "hpc sss 12 "
function trim() {
    $(eval echo ${1})
}

# 去掉所有空格
# 调用方式：函数名
# 调用举例：`all_trim` "hpc sss 12 "
function all_trim() {
    str_all_trim=$(echo ${1} | sed 's/[[:space:]]//g')
    echo ${str_all_trim}
}

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

# 测试连接ansible，3次重试ssh密码机会，超过则自动退出，
# 调用方式：函数名
# 调用举例：`test_ansible`
function test_ansible() {
    local count=0
    while [ $count -lt 3 ]
    do
      if [ -z "$(ansible ${ansible_group_name}":!"${om_machine_ip} -m ping | grep UNREACHABLE)" ]; then
        return
      elif [ -z "$(ansible ${ansible_group_name}":!"${om_machine_ip} -k -m ping | grep UNREACHABLE)" ]; then
        return
      else
        count=$((count+1))
        log_tips "Incorrect password. Please try again.[${count}/3]" true
      fi
      if [ $count -eq 3 ]; then
        log_tips "The password has been incorrect for more than three times. The system automatically logs out." true
        exit_and_cleanENV 0
      fi
    done

}

# 更新配置文件指定section指定key的vaLue
# 调用方式：函数名 section名称 属性key名称 新值
# 调用举例：`modify_ini_value` common_global_conf common_sys_user_password "hpc@123#456"
function modify_ini_value() {
    local section=${1}
    local key=${2}
    local new_value=${3}
    local section_num=$(sed -n -e "/\[${section}\]/=" ${ini_file})
    sed -i "${section_num},/^\[.*\]/s/\(${key}.\?=\).*/\1 ${new_value}/g" ${ini_file}
}

# 运维节点IP地址
om_machine_ip=$(get_ini_value basic_conf basic_om_master_ip)

# 以JSON字符串的方式获取操作系统信息
function os_info() {
    echo "{"
    local strList=''
    if [[ -e /etc/os-release ]]; then
        source /etc/os-release
        strList=${strList}"\"ID\": \"${ID}\","
        strList=${strList}"\"VERSION_ID\": \"${VERSION_ID}\","
        strList=${strList}"\"NAME\": \"${NAME}\","
        strList=${strList}"\"VERSION\": \"${VERSION}\","
        strList=${strList}"\"PRETTY_NAME\": \"${PRETTY_NAME}\","
    fi
    local kernel_name=$(uname -s)
    local kernel_vers=$(uname -v)
    local kernel_real=$(uname -r)
    local kernel_arch=$(uname -p)
    local kernel_os=$(uname -o)
    strList=${strList}"\"kernel_name\": \"${kernel_name}\","
    strList=${strList}"\"kernel_ver\": \"${kernel_vers}\","
    strList=${strList}"\"kernel_rel\": \"${kernel_real}\","
    strList=${strList}"\"kernel_arch\": \"${kernel_arch}\","
    strList=${strList}"\"kernel_os\": \"${kernel_os}\","
    local var=${strList%??}
    echo ${var}
    echo "}"
}

# 获取操作系统版本号
function os_version_id() {
    if [[ -e /etc/os-release ]]; then
        source /etc/os-release
        echo ${VERSION_ID}
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
LOG_PRE_NAME=$(date '+%Y-%m-%d %H:%M:%S:%3N')_${CURRENT_USER}_${FILE_NAME##*/}


# 检查并创建运行日志存放目录
if [ ! -d "${operation_log_path}/" ]; then
    mkdir -m 755 -p ${operation_log_path}/
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
        [ ${LOG_LEVEL} -le 1 ] && echo -e "\033[34m[DEBUG] ${1}\033[0m"
    else
        [ ${LOG_LEVEL} -le 1 ] && echo -e "\033[34m[DEBUG]" ${LOG_PRE_NAME} ${1}"\033[0m" >/dev/null
    fi
    [ ${LOG_LEVEL} -le 1 ] && echo -e "[DEBUG] ${LOG_PRE_NAME} ${1}" >>${operation_log_path}/access_all.log
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
        [ ${LOG_LEVEL} -le 2 ] && echo -e "\033[32m[INFO] ${1}\033[0m"
    else
        [ ${LOG_LEVEL} -le 2 ] && echo -e "\033[32m[INFO]" ${LOG_PRE_NAME} ${1}"\033[0m" >/dev/null
    fi
    [ ${LOG_LEVEL} -le 2 ] && echo -e "[INFO] ${LOG_PRE_NAME} ${1}" >>${operation_log_path}/access_all.log
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
        [ ${LOG_LEVEL} -le 3 ] && echo -e "\033[33m[WARN] ${1}\033[0m"
    else
        [ ${LOG_LEVEL} -le 3 ] && echo -e "\033[33m[WARN]" ${LOG_PRE_NAME} ${1}"\033[0m" >/dev/null
    fi
    [ ${LOG_LEVEL} -le 3 ] && echo -e "[WARN] ${LOG_PRE_NAME} ${1}" >>${operation_log_path}/access_all.log
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
        [ ${LOG_LEVEL} -le 4 ] && echo -e "\033[31m[ERROR] ${1}\033[0m"
    else
        [ ${LOG_LEVEL} -le 4 ] && echo -e "\033[31m[ERROR]" ${LOG_PRE_NAME} ${1}"\033[0m" >/dev/null
    fi
    [ ${LOG_LEVEL} -le 4 ] && echo -e "[ERROR] ${LOG_PRE_NAME} ${1}" >>${operation_log_path}/access_all.log
    [ ${LOG_LEVEL} -le 4 ] && echo -e "[ERROR] ${LOG_PRE_NAME} ${1}" >>${operation_log_path}/access_error.log
}

# 告知提示日志
# 调用方式：函数名 打印信息 是否打印到屏幕(值为true或false),无参数默认是打印到屏幕
# 调用举例：`log_tips` "print information" true
function log_tips() {
    local is_print_screen=$(all_trim ${2})
    if [ -z "${is_print_screen}" ]; then
        is_print_screen=true
    fi

    if [ "${is_print_screen}" == "true" ]; then
        [ ${LOG_LEVEL} -le 5 ] && echo -e "\033[32m${1}\033[0m"
    else
        [ ${LOG_LEVEL} -le 5 ] && echo -e "\033[32m[TIPS]" ${LOG_PRE_NAME} ${1}"\033[0m" >/dev/null
    fi
    [ ${LOG_LEVEL} -le 5 ] && echo -e "[TIPS] ${LOG_PRE_NAME} ${1}" >>${operation_log_path}/access_all.log
}

# 一直都会打印的日志
# 调用方式：函数名
# 调用举例：`view_log_path`
function view_log_path() {
    echo -e ""
    echo -e "\033[33m##########################################################################\033[0m"
    echo -e "\033[33m##\033[0m"
    echo -e "\033[33m##\033[0m\033[32m  运行日志：${operation_log_path}/access_all.log"
    echo -e "\033[33m##\033[0m\033[32m  错误日志：${operation_log_path}/access_error.log"
    echo -e "\033[33m##\033[0m"
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
        exit_and_cleanENV 1
    fi

    if [ ! -f ${filePath} ]; then
        echo "属性文件（${filePath}） 不存在。"
        echo "" >&2
        exit_and_cleanENV 1
    fi

    if [ ! -r ${filePath} ]; then
        echo "当前用户不具有对属性文件（${filePath}）的可读权限。"
        echo "" >&2
        exit_and_cleanENV 1
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
        yum install -y net-tools >> ${operation_log_path}/access_all.log 2>&1
    fi
    echo "$(ifconfig -a 2> /dev/null | grep inet | grep -v 127.0.0.1 | grep -v inet6 | awk '{print $2}' | tr -d "addrs")"
}

# 获取当前主机的主机名称hostname
# 调用方式：函数名
# 调用举例：`get_current_host_name`
function get_current_host_name() {
    echo "$(cat /etc/hostname)"
}

# 从hostname.csv文件中获取当前主机的主机业务分组名称
# 调用方式：函数名
# 调用举例：`get_current_host_group`
function get_current_host_group() {
    local group_name="unknown group"
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
        log_error "${hostname_file} file doesn't exist." false
    fi
    echo ${group_name}
}

# 获取当前主机的主机名称hostname和IP地址，主要用于输出打印信息
# 调用方式：函数名
# 调用举例：`get_current_host_info`
function get_current_host_info() {
    echo "[$(get_current_host_ip)_$(get_current_host_name)]"
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
    if [ -z "$(lspci | grep -i nvidia)" ]; then
        echo 1
    else
        echo 0
    fi
}

# 检查执行的命令是否存在
# 调用方式：函数名 待执行命令
# 返回值：0不存在，1代表存在
# 调用举例：`is_command_exist` tar
function is_command_exist() {
    local ret='0'
    command -v ${1} >/dev/null 2>&1 || { local ret='1'; }
    if [ "${ret}" == "0" ]; then
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
            return 1
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
         if [ "${6}" == "true" ]; then
            ${5}
         fi
         return
    fi
    if [ "${is_manual_script}" != "true" ]; then
         log_error "Please input a valid parameter <true>. Example: *.sh true" true
         return
    fi
    # 手动选择需要执行的方法
    log_tips "Please select the method to execute." true
    select action_var in "check" "config or install" "system exit"; do
        if [ "${action_var}" == "check" ]; then
            ${4}
        elif [ "${action_var}" == "config or install" ]; then
            ${5}
        elif [ "${action_var}" == "system exit" ]; then
            exit_and_cleanENV 0
        else 
            log_error "selected drop-down list does not match the defined, please select again." true
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
        log_error "[${1}] directory is empty." false
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
        log_error "Input parameter is blank." false
    fi
}

# 获取基础配置所需安装依赖软件包所在文件夹
# 调用方式：函数名
# 返回值：文件夹路径
# 调用举例：`get_sourcecode_dir`
function get_sourcecode_dir() {
    if [ "${root_dir}" == "opt" ]; then
        # 适配初始化时获取软件或者依赖包
        echo /${root_dir}/hpcpilot/sourcecode
    else
        echo $(get_ini_value basic_conf basic_shared_directory /share)/software/sourcecode
    fi
}

# 检查校验ROOT用户密码是否正确
# 调用方式：函数名 ip地址
# 返回值：0=合法 1=非法
# 调用举例：`valid_ip_address` 10.98.21.33
function valid_root_password() {
    local ip_address=${1}
    local ret_code=0
    # 使用正则表达式校验IP地址格式是否符合规范
    if [[ ${ip_address} =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
        # 对IP地址进行拆分
        IFS='.' read -r -a ip_parts <<< "${ip_address}"
        for ip_part in "${ip_parts[@]}"; do
            if (( ${ip_part} < 0 || ${ip_part} > 255)); then
                ret_code=1
                break
            fi
        done
    else
        ret_code=1
    fi
    echo ${ret_code}
}

# 验证IP地址的合法性（校验格式和校验数字在0-255之间）
# 调用方式：函数名 ip地址
# 返回值：0=合法 1=非法
# 调用举例：`valid_ip_address` 10.98.21.33
function valid_ip_address() {
    local ip_address=${1}
    local ret_code=0
    # 使用正则表达式校验IP地址格式是否符合规范
    if [[ ${ip_address} =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
        # 对IP地址进行拆分
        IFS='.' read -r -a ip_parts <<< "${ip_address}"
        for ip_part in "${ip_parts[@]}"; do
            if (( ${ip_part} < 0 || ${ip_part} > 255)); then
                ret_code=1
                break
            fi
        done
    else
        ret_code=1
    fi
    echo ${ret_code}
}

# 验证主机名hostname的合法性（最多为64个字符，仅可包含“.”、“_”、“-”、“a-z”、“A-Z”和“0-9”这些字符，并且不能以“.”打头和结尾，也不能两个“.”连续）
# 调用方式：函数名 ip地址
# 返回值：0=合法 1=非法
# 调用举例：`valid_hostname` arm_47
function valid_hostname() {
    local hostname=${1}
    if [ -z "${hostname}" ] || [ ${#hostname} -gt 64 ]; then
        log_error "[${hostname}] is blank or length is greater than 64." false
        return 1
    fi
    # 特殊标记主要用来替换“.”后进行判断是否包含“.”
    local special_flag=cphdilav
    # 判断不能以“.”打头和结尾，也不能两个及以上的“.”连续
    if [[ "${hostname/./${special_flag}}" =~ ^"${special_flag}"* ]] || [[ "${hostname/%./${special_flag}}" =~ "${special_flag}"$ ]] || [[ "${hostname//./${special_flag}}" =~ "${special_flag}${special_flag}" ]]; then
        log_error "[${hostname}] can not start or end with a period (.) or two consecutive periods (.)." false
        return 1
    fi
    # 去掉所有特殊符号“.” "-" "_"
    local var=${hostname//./${special_flag}}
    # 去掉所有特殊符号“-”
    var=${var//-/${special_flag}}
    # 去掉所有特殊符号“_”
    var=${var//_/${special_flag}}
    # 判断是否仅包含“a-z”、“A-Z”和“0-9”字符
    if [[ ${var} =~ ^[a-zA-Z0-9]+$ ]]; then
        return 0
    else
        log_error "[${hostname}] contains [a-z] [A-Z] and [0-9] only." false
        return 1
    fi
}

# 检查使用初始化序列创建业务用户时用户ID是否被使用
# 调用方式：函数名
# 返回值：0=合法 1=非法
# 调用举例：`check_sequence_used`
function check_sequence_used() {
    local init_sequence_value=$(get_ini_value basic_conf basic_userid_init_sequence 60000)
    local hostname_file=${base_directory}/hostname.csv
}

# 对ANSIBLE shell执行结果进行简单的统计分析
# 调用方式：函数名
# 返回值：无
# 调用举例：`ansible_shell_stats`
function ansible_shell_stats() {
    if [ ! -d "${ansible_log_path}" ] || [ -z "$(ls ${ansible_log_path})" ]; then
        log_warn "[${ansible_log_path}] directory or ansible logs doesn't exist, statistics cannot be collected." 
        return
    fi
    local files=$(ls ${ansible_log_path})
    local total_count=0
    local success_count=0
    local fail_count=0
    local fail_machine_ip=""
    # 解析ANSIBLE执行日志结果
    for file_name in ${files}; do
        total_count=$((${total_count}+1))
        local rc=$(cat ${ansible_log_path}/${file_name} | jq -r '.rc')
        local stderr=$(cat ${ansible_log_path}/${file_name} | jq -r '.stderr')
        local msg=$(cat ${ansible_log_path}/${file_name} | jq -r '.msg')
        if [ "${rc}" == "0" ] && [ -z "${msg}" ] && [ -z "${stderr}" ]; then
            success_count=$((${success_count}+1))
        else
            fail_count=$((${fail_count}+1))
            fail_machine_ip="${fail_machine_ip}\n${file_name}"
        fi
    done
    # 输出打印统计信息
    echo -e "\033[33m=============================当前执行结果统计=============================\033[0m"
    echo -e "\033[33m==\033[0m\033[32m  执行节点总数: ${total_count}\033[0m"
    echo -e "\033[33m==\033[0m\033[32m  成功节点总数: ${success_count}\033[0m"
    echo -e "\033[33m==\033[0m\033[32m  失败节点总数:\033[0m\033[31m ${fail_count}\033[0m"
    if [ -n "${fail_machine_ip}" ]; then
        echo -e "\033[33m==\033[0m\033[32m  失败节点IP列表: \033[0m"
        echo -e "\033[31m  ${fail_machine_ip}\033[0m"
        echo -e "\033[33m详细错误信息可查看日志[${ansible_log_path}/]\033[0m"
    fi
    echo -e "\033[33m=============================当前执行结果统计=============================\033[0m"
}

# 对ANSIBLE COPY目录执行结果进行简单的统计分析
# 调用方式：函数名
# 返回值：无
# 调用举例：`ansible_copy_stats`
function ansible_copy_stats() {
    if [ ! -d "${ansible_log_path}" ] || [ -z "$(ls ${ansible_log_path})" ]; then
        log_warn "[${ansible_log_path}] directory or ansible logs doesn't exist, statistics cannot be collected." 
        return
    fi
    local files=$(ls ${ansible_log_path})
    local total_count=0
    local success_count=0
    local fail_count=0
    local fail_machine_ip=""
    # 解析ANSIBLE执行日志结果
    for file_name in ${files}; do
        total_count=$((${total_count}+1))
        local msg=$(cat ${ansible_log_path}/${file_name} | jq -r '.msg')
        if [ "${msg}" == "null" ] || [ -z "${msg}" ]; then
            success_count=$((${success_count}+1))
        else
            fail_count=$((${fail_count}+1))
            fail_machine_ip="${fail_machine_ip}\n${file_name}"
        fi
    done
    # 输出打印统计信息
    echo -e "\033[33m=============================当前执行结果统计=============================\033[0m"
    echo -e "\033[33m==\033[0m\033[32m  执行节点总数: ${total_count}\033[0m"
    echo -e "\033[33m==\033[0m\033[32m  成功节点总数: ${success_count}\033[0m"
    echo -e "\033[33m==\033[0m\033[32m  失败节点总数:\033[0m\033[31m ${fail_count}\033[0m"
    if [ -n "${fail_machine_ip}" ]; then
        echo -e "\033[33m==\033[0m\033[32m  失败节点IP列表: \033[0m"
        echo -e "\033[31m  ${fail_machine_ip}\033[0m"
        echo -e "\033[33m详细错误信息可查看日志[${ansible_log_path}/]\033[0m"
    fi
    echo -e "\033[33m=============================当前执行结果统计=============================\033[0m"
}


# 对ANSIBLE执行结果进行简单的统计分析（适用于封装的批量执行脚本）
# 调用方式：函数名
# 返回值：无
# 调用举例：`ansible_run_stats`
function ansible_run_stats() {
    if [ ! -d "${ansible_log_path}" ] || [ -z "$(ls ${ansible_log_path})" ]; then
        log_warn "[${ansible_log_path}] directory or ansible logs doesn't exist, statistics cannot be collected." 
        return
    fi
    local files=$(ls ${ansible_log_path})
    local total_count=0
    local success_count=0
    local fail_count=0
    local fail_machine_ip=""
    # 解析ANSIBLE执行日志结果
    for file_name in ${files}; do
        total_count=$((${total_count}+1))
        local changed=$(cat ${ansible_log_path}/${file_name} | jq -r '.changed')
        local rc=$(cat ${ansible_log_path}/${file_name} | jq -r '.rc')
        local stderr=$(cat ${ansible_log_path}/${file_name} | jq -r '.stderr')
        local stdout=$(cat ${ansible_log_path}/${file_name} | jq -r '.stdout' | grep -w "\[ X \]")
        local msg=$(cat ${ansible_log_path}/${file_name} | jq -r '.msg')
        if [ -n "${stderr}" ] || [ -n "${stdout}" ] || [ -n "${msg}" -a "${msg}" != "null" ]; then
            if [ -n "$(echo "${stderr}" | grep -i "Created symlink")" ] || [ -n "$(echo "${stderr}" | grep -i "Warning")" ]; then
                success_count=$((${success_count}+1))
            else
                fail_count=$((${fail_count}+1))
                fail_machine_ip="${fail_machine_ip}\n${file_name}"  
            fi
        else
            success_count=$((${success_count}+1))
        fi
    done
    # 输出打印统计信息
    echo -e "\033[33m=============================当前执行结果统计=============================\033[0m"
    echo -e "\033[33m==\033[0m\033[32m  执行节点总数: ${total_count}\033[0m"
    echo -e "\033[33m==\033[0m\033[32m  成功节点总数: ${success_count}\033[0m"
    echo -e "\033[33m==\033[0m\033[32m  失败节点总数:\033[0m\033[31m ${fail_count}\033[0m"
    if [ -n "${fail_machine_ip}" ]; then
        echo -e "\033[33m==\033[0m\033[32m  失败节点IP列表: \033[0m"
        echo -e "\033[31m  ${fail_machine_ip}\033[0m"
        echo -e "\033[33m详细错误信息可查看日志[${ansible_log_path}/]\033[0m"
    fi
    echo -e "\033[33m=============================当前执行结果统计=============================\033[0m"
}

# 获取日志文件
# 调用方式：函数名
# 返回值：日志文件
# 调用举例：`hpc_pilot_log`
function hpc_pilot_log() {
    # yum install *.rpm >spark.log 只输出正确日志
    # yum install *.rpm 2>spark.log 只输出错误日志
    # yum install *.rpm >spark.log 2>&1 输出全部日志
    # 如果想标准输出和错误信息都不显示，可以重定向到/dev/null中
    # 输出全部安装过程日志
    echo "${operation_log_path}/access_all.log 2>&1"
}

# 在运维节点生成SSHKEY
# 调用方式：函数名
# 返回值：无
# 调用举例：`create_local_sshkey`
function create_local_sshkey() {
    # 生成sshkey相关文件
    \rm ~/.ssh/id_rsa* -f
    ssh-keygen -t rsa -f ~/.ssh/id_rsa -N "" -q
    cat ~/.ssh/id_rsa.pub > ~/.ssh/authorized_keys
    chmod 600 /root/.ssh
    
    cd /root
    log_info "Sshkey of the local O&M node is generated." false
}

# 通过配置文件setting.ini判断ldap服务是否是HA环境
# 调用方式：函数名
# 返回值：0=表示非HA，1=表示HA
# 调用举例：`ldap_is_HA`
function ldap_is_HA() {
    local ldap_slave_ip=$(get_ini_value service_conf slave_ldap_server_ip)
    local ldap_virtual_ip=$(get_ini_value service_conf virtual_ldap_server_ip)
    if [ -n "$(all_trim ${ldap_slave_ip})" ] && [ -n "$(all_trim ${ldap_virtual_ip})" ]; then
        return 1
    else
        return 0
    fi
}

# 读取hostname.csv文件并生成/etc/hosts文件
# 调用方式：函数名
# 返回值：无
# 调用举例：`create_etc_hosts`
function create_etc_hosts() {
    if [ "$(is_file_exist ${hostname_file})" == "0" ]; then
        local is_ha=0
        local hosts_content="127.0.0.1   localhost localhost.localdomain localhost4 localhost4.localdomain4\n::1         localhost localhost.localdomain localhost6 localhost6.localdomain6\n"
        local ldap_domain=$(get_ini_value service_conf ldap_domain_name ldap01.huawei.com)
        local ldap_master_ip=$(get_ini_value service_conf master_ldap_server_ip)
        ldap_is_HA
        if [ "${?}" == "1" ]; then
            local ldap_virtual_ip=$(get_ini_value service_conf virtual_ldap_server_ip)
            # HA环境直接将虚拟IP和域名映射
            hosts_content="${hosts_content}${ldap_virtual_ip} ${ldap_domain}\n"
            is_ha=1
        fi
        # tail -n +2 从第二行开始读取数据，第一行为标题行
        for line in $(cat ${hostname_file} | tail -n +2); do
            # 检查判断字符串长度是否为0
            if [ -n "${line}" ]; then
                local file_host_ip=$(echo ${line} | awk -F "," '{print $1}')
                local file_host_name=$(echo ${line} | awk -F "," '{print $2}')
                if [ "${is_ha}" == "0" ] && [ "${file_host_ip}" == "${ldap_master_ip}" ]; then
                    hosts_content="${hosts_content}${file_host_ip} ${file_host_name} ${ldap_domain}\n"
                else
                    hosts_content="${hosts_content}${file_host_ip} ${file_host_name}\n"
                fi
            fi
        done
        # 覆盖写入/etc/hosts文件
        echo -ne "${hosts_content}" >/etc/hosts
    else
        log_error "[${hostname_file}] file doesn't exist, please check." false
        exit_and_cleanENV 1
    fi
}

# 读取hostname.csv文件并生成/etc/ansible/hosts文件
# 调用方式：函数名
# 返回值：无
# 调用举例：`create_ansible_hosts`
function create_ansible_hosts() {
    if [ "$(is_file_exist ${hostname_file})" == "0" ]; then
        local ccsccp=""
        local agent_ip=""
        local scheduler_ip=""
        local portal_ip=""
        local cli_ip=""
        local ntp_server_ip=""
        local ntp_client_ip=""
        local ldap_client_ip=""
        # 扩容分组
        local expansion_ip=""

        # tail -n +2 从第二行开始读取数据，第一行为标题行
        for line in $(cat ${hostname_file} | tail -n +2); do
            # 检查判断字符串长度是否为0
            if [ -n "${line}" ]; then
                local file_host_ip=$(echo ${line} | awk -F "," '{print $1}')
                # 检查是否存在新增扩容节点
                if [ "$(echo ${line} | awk -F "," '{print $4}' | sed -e 's/\r//g')" == "1" ]; then
                    if [ -z "${expansion_ip}" ]; then
                        expansion_ip="${file_host_ip}"
                    else
                        expansion_ip="${expansion_ip}\n${file_host_ip}"
                    fi
                fi
                local group_names="$(echo ${line} | awk -F "," '{print $3}')"
                if [ -n "${group_names}" ]; then
                    local arr_group=(${group_names//&/ })
                    for group_name in "${arr_group[@]}"; do
                        if [ -n "$(echo ${group_name} | grep -i -w 'ccsccp')" ]; then
                            if [ -z "${ccsccp}" ]; then
                                ccsccp="${file_host_ip}"
                            else
                                # 检查是否配置了重复的分组名称
                                if [ -z "$(echo -n "${ccsccp}" | grep "${file_host_ip}")" ]; then
                                    ccsccp="${ccsccp}\n${file_host_ip}"
                                fi
                            fi
                        fi
                        if [ -n "$(echo ${group_name} | grep -i -w 'agent')" ]; then
                            if [ -z "${agent_ip}" ]; then
                                agent_ip="${file_host_ip}"
                            else
                                # 检查是否配置了重复的分组名称
                                if [ -z "$(echo -n "${agent_ip}" | grep "${file_host_ip}")" ]; then
                                    agent_ip="${agent_ip}\n${file_host_ip}"
                                fi
                            fi
                        fi
                        if [ -n "$(echo ${group_name} | grep -i -w 'scheduler')" ]; then
                            if [ -z "${scheduler_ip}" ]; then
                                scheduler_ip="${file_host_ip}"
                            else
                                # 检查是否配置了重复的分组名称
                                if [ -z "$(echo -n "${scheduler_ip}" | grep "${file_host_ip}")" ]; then
                                    scheduler_ip="${scheduler_ip}\n${file_host_ip}"
                                fi
                            fi
                        fi
                        if [ -n "$(echo ${group_name} | grep -i -w 'portal')" ]; then
                            if [ -z "${portal_ip}" ]; then
                                portal_ip="${file_host_ip}"
                            else
                                # 检查是否配置了重复的分组名称
                                if [ -z "$(echo -n "${portal_ip}" | grep "${file_host_ip}")" ]; then
                                    portal_ip="${portal_ip}\n${file_host_ip}"
                                fi
                            fi
                        fi
                        if [ -n "$(echo ${group_name} | grep -i -w 'cli')" ]; then
                            if [ -z "${cli_ip}" ]; then
                                cli_ip="${file_host_ip}"
                            else
                                # 检查是否配置了重复的分组名称
                                if [ -z "$(echo -n "${cli_ip}" | grep "${file_host_ip}")" ]; then
                                    cli_ip="${cli_ip}\n${file_host_ip}"
                                fi
                            fi
                        fi
                        if [ -n "$(echo ${group_name} | grep -i -w 'ntp_server')" ]; then
                            if [ -z "${ntp_server_ip}" ]; then
                                ntp_server_ip="${file_host_ip}"
                            else
                                # 检查是否配置了重复的分组名称
                                if [ -z "$(echo -n "${ntp_server_ip}" | grep "${file_host_ip}")" ]; then
                                    ntp_server_ip="${ntp_server_ip}\n${file_host_ip}"
                                fi
                            fi
                        fi
                        if [ -n "$(echo ${group_name} | grep -i -w 'ntp_client')" ]; then
                            if [ -z "${ntp_client_ip}" ]; then
                                ntp_client_ip="${file_host_ip}"
                            else
                                # 检查是否配置了重复的分组名称
                                if [ -z "$(echo -n "${ntp_client_ip}" | grep "${file_host_ip}")" ]; then
                                    ntp_client_ip="${ntp_client_ip}\n${file_host_ip}"
                                fi
                            fi
                        fi   
                        if [ -n "$(echo ${group_name} | grep -i -w 'ldap_client')" ]; then
                            if [ -z "${ldap_client_ip}" ]; then
                                ldap_client_ip="${file_host_ip}"
                            else
                                # 检查是否配置了重复的分组名称
                                if [ -z "$(echo -n "${ldap_client_ip}" | grep "${file_host_ip}")" ]; then
                                    ldap_client_ip="${ldap_client_ip}\n${file_host_ip}"
                                fi
                            fi
                        fi
                    done
                fi
            fi
        done
        # 追加写入/etc/ansible/hosts文件
        :>/etc/ansible/hosts
        if [ -n "${ccsccp}" ]; then
            echo -ne "[ccsccp]\n" >>/etc/ansible/hosts
            echo -ne "${ccsccp}" >>/etc/ansible/hosts
        fi
        if [ -n "${agent_ip}" ]; then
            echo -ne "\n[agent]\n" >>/etc/ansible/hosts
            echo -ne "${agent_ip}" >>/etc/ansible/hosts  
        fi
        if [ -n "${scheduler_ip}" ]; then
            echo -ne "\n[scheduler]\n" >>/etc/ansible/hosts
            echo -ne "${scheduler_ip}" >>/etc/ansible/hosts  
        fi
        if [ -n "${portal_ip}" ]; then
            echo -ne "\n[portal]\n" >>/etc/ansible/hosts
            echo -ne "${portal_ip}" >>/etc/ansible/hosts  
        fi
        if [ -n "${cli_ip}" ]; then
            echo -ne "\n[cli]\n" >>/etc/ansible/hosts
            echo -ne "${cli_ip}" >>/etc/ansible/hosts  
        fi
        if [ -n "${ntp_server_ip}" ]; then
            echo -ne "\n[ntp_server]\n" >>/etc/ansible/hosts
            echo -ne "${ntp_server_ip}" >>/etc/ansible/hosts
        fi
        if [ -n "${ntp_client_ip}" ]; then
            echo -ne "\n[ntp_client]\n" >>/etc/ansible/hosts
            echo -ne "${ntp_client_ip}" >>/etc/ansible/hosts
        fi
        if [ -n "${ldap_client_ip}" ]; then
            echo -ne "\n[ldap_client]\n" >>/etc/ansible/hosts
            echo -ne "${ldap_client_ip}" >>/etc/ansible/hosts
        fi
        if [ -n "${expansion_ip}" ]; then
            echo -ne "\n[expansion]\n" >>/etc/ansible/hosts
            echo -ne "${expansion_ip}" >>/etc/ansible/hosts  
        fi
    else
        log_error "[${hostname_file}] file doesn't exist, please check." false
        exit_and_cleanENV 1
    fi
}

# 通过hostname.csv文件判断是否是进行扩容操作
# 调用方式：check_run_expansion
# # 返回值：0=非扩容 1=扩容
# 调用举例：`check_run_expansion`
function check_run_expansion() {
    local is_expansion=0
    if [ "$(is_file_exist ${hostname_file})" == "0" ]; then
        # tail -n +2 从第二行开始读取数据，第一行为标题行
        for line in $(cat ${hostname_file} | tail -n +2); do
            # 检查判断字符串长度是否为0
            if [ -n "${line}" ]; then
                local expansion=$(echo ${line} | awk -F "," '{print $4}' | sed -e 's/\r//g')
                if [ -n "${expansion}" ] && [ "${expansion}" == "1" ]; then
                    is_expansion=1
                    break
                fi
            fi
        done
    else
        log_error "[${hostname_file}] file doesn't exist, please check." false
        exit_and_cleanENV 1
    fi
    echo ${is_expansion}
}

# 系统退出并清理密码
# 调用方式：exit_and_cleanENV 退出编码 是否手动执行（true or false）
# 返回值：无
# 调用举例：`exit_and_cleanENV` 0 true
function exit_and_cleanENV() {
    if [ -z "${auto_run_flag}" ] || [ "${auto_run_flag}" == "false" ]; then
        exit ${1}
    fi
    if [ -z "${2}" ] || [ "${2}" == "true" ]; then
        #清理配置文件涉及到的密码
        modify_ini_value common_global_conf common_sys_user_password ""
        modify_ini_value common_global_conf common_sys_root_password ""
        modify_ini_value service_conf ldap_login_password ""
        # 清理ANSIBLE运行日志
        if [ -d "${ansible_log_path}" ]; then
            rm -rf ${ansible_log_path}/*
        fi
        # 清理删除hpcpilot.pid
        if [ -f "/var/log/hpcpilot.pid" ]; then
            rm -rf /var/log/hpcpilot.pid
        fi
        log_warn "Password is cleared, config password when you run scripts again." true
    fi
    exit ${1}
}

function expect_ssh_command() {
  local ip="$1"
  local pw="$2"
  local cmd="$3"
  local show_info="$4"
  local time_out="$5"

  local expect_show="0"
  [ "${show_info}" = "true" ] && expect_show="1"
  [ -z "${time_out}" ] && time_out=120

  expect <<EOF
    log_user "${expect_show}"
    set timeout "${time_out}"
    spawn bash -c {ssh -o StrictHostKeyChecking=no -o ServerAliveInterval=10 -o ServerAliveCountMax=3 -o NumberOfPasswordPrompts=1 root@${ip} "${cmd}"}
    expect {
        "yes/no" { send "yes\n";exp_continue }
        "password:" { send -- "${pw}\n" }
        default { exit 1 }
    }
    expect eof
    catch wait result;
    exit [lindex \$result 3]
EOF
  local result=$?
  return $result
}

function ssh_command() {
  local ip="$1"
  local cmd="$2"
  local pw="$3"
  local show_info="$4"
  local time_out="$5"

  local ssh_show="-q"
  local blank_set="> /dev/null 2>&1"
  if [ "${show_info}" = "true" ]; then
    ssh_show=""
    blank_set=""
  fi
  ssh root@${ip} -o StrictHostKeyChecking=no -o ServerAliveInterval=10 -o ServerAliveCountMax=3 -o PasswordAuthentication=no "uname"
  if [ 0 = $? ]; then
    ssh -o StrictHostKeyChecking=no -o ServerAliveInterval=10 -o ServerAliveCountMax=3 ${ssh_show} root@${ip} "${cmd}" "${blank_set}"
  else
    expect_ssh_command "${ip}" "${pw}" "${cmd}" "${show_info}" "${time_out}"
  fi
  local result=$?
  return $result
}

# 针对异常非法中断处理
#trap "handle_ctrlc" EXIT
#function handle_ctrlc() {
#    log_warn "Abnormal interruption [CTRL+C] exit." false
#	# 清理配置文件涉及到的密码
##    modify_ini_value common_global_conf common_sys_user_password ""
##    modify_ini_value common_global_conf common_sys_root_password ""
##    modify_ini_value service_conf ldap_login_password ""
#    # 清理ANSIBLE运行日志
#    if [ -d "${ansible_log_path}" ]; then
#        rm -rf ${ansible_log_path}/*  
#    fi
#    # 清理删除hpcpilot.pid
#    if [ -f "/var/log/hpcpilot.pid" ]; then
#        rm -rf /var/log/hpcpilot.pid
#    fi
#    log_warn "Password is cleared, config password when you run scripts again." true
#    exit 1
#}

# 检查并安装基础命令
# 调用方式：basic_commands_install
# 返回值：无
# 调用举例：`basic_commands_install`
function basic_commands_install() {
    yum list 1>/dev/null 2>/dev/null
    if [ $? -eq 1 ]; then
        log_error "Yum source is not configured." false
        return
    fi
    # 列举定义基础命令
    local basic_commands=(net-tools sshpass tree jq tar curl grep sed awk gcc-c++ tcsh)
    for (( i = 0; i < ${#basic_commands[@]}; i++ )); do
        if [ "$(rpm -qa ${basic_commands[i]})" == "" ]; then
            if [ "$(yum list | grep ${basic_commands[i]})" == "" ]; then
                # 特殊处理sshpass依赖服务
                if [ "${basic_commands[i]}" == "sshpass" ]; then
                    if [ -z "$(find_file_by_path ${sourcecode_dir}/ansible/ sshpass rpm)" ]; then
                        log_error "[${basic_commands[i]}] command cannot be found in the yum source." false
                    else
                        cd ${sourcecode_dir}/ansible/
                        yum install -y ${basic_commands[i]} >> ${operation_log_path}/access_all.log 2>&1
                        log_info "[${basic_commands[i]}] command installation succeeded." false
                    fi
                else
                    log_error "[${basic_commands[i]}] command cannot be found in the yum source." false  
                fi
                if [ "${basic_commands[i]}" == "tcsh" ]; then
                    if [ -z "$(find_file_by_path ${sourcecode_dir}/ tcsh rpm)" ]; then
                        log_error "[${basic_commands[i]}] command cannot be found in the yum source." false
                    else
                        cd ${sourcecode_dir}/
                        yum install -y ${basic_commands[i]} >> ${operation_log_path}/access_all.log 2>&1
                        log_info "[${basic_commands[i]}] command installation succeeded." false
                    fi
                else
                    log_error "[${basic_commands[i]}] command cannot be found in the yum source." false  
                fi
                # 特殊处理jq依赖服务
                if [ "${basic_commands[i]}" == "jq" ]; then
                    if [ -z "$(find_file_by_path ${sourcecode_dir}/jq/ jq rpm)" ]; then
                        log_error "[${basic_commands[i]}] command cannot be found from native." false
                    else
                        cd ${sourcecode_dir}/jq/
                        yum localinstall -y *.rpm >> ${operation_log_path}/access_all.log 2>&1
                        log_info "[${basic_commands[i]}] command installation succeeded." false
                    fi
                else
                    log_error "[${basic_commands[i]}] command cannot be found in the yum source." false  
                fi
            else
                yum install -y ${basic_commands[i]} >> ${operation_log_path}/access_all.log 2>&1
                log_info "[${basic_commands[i]}] command installation succeeded." false
            fi
        else
            log_info "[${basic_commands[i]}] command does not need to be installed." false
        fi
    done
}

# 判断脚本是否存在并发执行，如果存在则提醒不能执行，否则可执行
# 调用方式：check_concurrent_execution
# 返回值：0=可执行 1=不可执行
# 调用举例：`check_concurrent_execution`
function check_concurrent_execution() {
    local pid_file=/var/log/hpcpilot.pid
    if [ -s ${pid_file} ]; then
        local spid=$(cat ${pid_file})
        if [ -e /proc/${spid}/status ]; then
            return 1
        fi
        cat /dev/null > ${pid_file}
    fi
    echo $$ > ${pid_file}
    return 0
}

# 根据setting.ini配置的域名获取LDAP DC值
# 调用方式：get_ldapdc_by_domain
# 返回值：返回数组.示例:arr[0]=huawei,arr[0]=com
# 调用举例：`get_ldapdc_by_domain`
function get_ldapdc_by_domain() {
    # 定义数组返回变量并赋默认值
    local arr_dc=(huawei com)
    local ldap_domain=$(get_ini_value service_conf ldap_domain_name ldap01.huawei.com)
    if [ "${ldap_domain}" != "ldap01.huawei.com" ]; then
        # 截取最后一个点后面的值
        if [ -n "${ldap_domain##*.}" ]; then
            arr_dc[1]=${ldap_domain##*.}
        fi
        local temp_dc0=${ldap_domain#*.}
        if [ -n "${temp_dc0%.*}" ]; then
            arr_dc[0]=${temp_dc0%.*}
        fi
    fi
    echo ${arr_dc[*]}
}

# 根据Benchmark模块加载对应的环境变量
# 调用方式：load_benchmark_env 模块名称数组
# 调用参数：BiSheng HMPI KML
# 返回值：无
# 调用举例：`load_benchmark_env` "BiSheng HMPI KML"
function load_benchmark_env() {
    if [ -z "${1}" ]; then
        log_error "Module parameters cannot be empty." true
        return
    fi
    local public_path=$(get_ini_value basic_conf basic_shared_directory /share)/software
    cd ${public_path}
    if [ -z "$(rpm -qa environment-modules)" ]; then
        yum install environment-modules -y -q
    fi
    source /etc/profile.d/modules.sh
    module use $PWD/modules

    local arr_module=(${1// / })
    for module_name in "${arr_module[@]}"; do
        if [ "${module_name}" == "BiSheng" ]; then
            local bisheng_path=`echo $PWD/sourcecode/*compiler*`
            local bisheng_v=`echo "$bisheng_path" | awk -F'/' '{print $5}' | awk -F'-' '{print $3}'`
            module load compilers/bisheng/$bisheng_v/bisheng$bisheng_v
        elif [ "${module_name}" == "HMPI" ]; then
            local bisheng_path=`echo $PWD/sourcecode/*compiler*`
            local bisheng_v=`echo "$bisheng_path" | awk -F'/' '{print $5}' | awk -F'-' '{print $3}'`
            local hmpi_path=`echo $PWD/sourcecode/Hyper-MPI*`
            local hmpi_v=`echo "$hmpi_path" | awk -F'/' '{print $5}' | awk -F'_' '{print $2}'`
            module load mpi/hmpi/$hmpi_v/bisheng$bisheng_v
        elif [ "${module_name}" == "KML" ]; then
            local kml_path=`echo $PWD/sourcecode/BoostKit-kml*`
            local kml_v=`echo "$kml_path" | awk -F'/' '{print $5}' | awk -F'_' '{print $2}'`
            module load libs/kml/$kml_v/kml$kml_v
        else
            log_warn "Unknown module name [${module_name}]." true
        fi
    done
}