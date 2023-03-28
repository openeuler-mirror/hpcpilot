# Copyright (c) Huawei Technologies Co., Ltd. 2022-2022. All rights reserved.
#

#!/usr/bin/env bash
# 挂载YUM镜像源自动化脚本

# 引用公共函数文件开始
source /${3}/software/tools/hpc_script/common.sh ${3}
# 引用公共函数文件结束

# YUM镜像文件存放路径
sourcecode_dir=$(get_sourcecode_dir)
# YUM镜像文件名
yum_iso_file_name=""
# YUM镜像安装挂载路径
yum_install_path=mnt
# 获取运维节点机器IP地址
is_om_machine=$(get_ini_value basic_conf basic_om_master_ip)

# 检查配置文件/etc/yum.repos.d/local.repo是否配置正确
# 返回0表示配置正确，1表示配置不正确
function check_local_repo() {
    local var1=$(grep "name=local" /etc/yum.repos.d/local.repo)
    local var2=$(grep "baseurl=file:///${yum_install_path}/" /etc/yum.repos.d/local.repo)
    local var3=$(grep "enabled=1" /etc/yum.repos.d/local.repo)
    local var4=$(grep "gpgcheck=0" /etc/yum.repos.d/local.repo)
    if [ -z "${var1}" ] || [ -z "${var2}" ] || [ -z "${var3}" ] || [ -z "${var4}" ]; then
        echo 1
    else
        echo 0
    fi
}

# 在文件夹中找到ISO YUM源
# 不支持文件夹中有多个相同类型（X86 ARM64）操作系统ISO
function find_os_yum() {
    # 当前操作系统名称
    local current_os_info=($(cat /etc/system-release))
    ############### 遍历文件夹下所有ISO文件并查找当前系统对应的ISO ###############
    local files=$(ls ${sourcecode_dir}/)
    if [ -n "${files}" ]; then
        for file_name in ${files}; do
            # 判断字符串是否以XXX字符串开头
            if [[ "${file_name}" =~ ^"yum_${current_os_info[0]}"* ]]; then
                yum_iso_file_name=${file_name}
                break
            fi
            if [ "${file_name##*.}" == "iso" ] && [[ "${file_name}" =~ "${current_os_info[0]}" ]]; then
                yum_iso_file_name=${file_name}
                break
            fi
        done  
    else
        log_error "$(get_current_host_info)_[${sourcecode_dir}] directory is empty." false
    fi
    # 检查当前操作系统类型的ISO文件是否找到
    if [ "${current_os_yum_iso}" == "" ]; then
        log_error "current system [${current_os_info[0]}] iso file is not found." false
    fi
}

# 检查yum安装配置是否正确
function check_yum_server() {
    # 定义返回结果 0=本地已挂载 1=未挂载 2=已挂载网络源
    local ret_code_mount="0"
    # 定义返回配置开机自动加载 0=已配置 1=未配置
    local ret_code_auto_start="0"
    # 检查*.repo文件配置是否正确 0=正确 1=不正确
    local ret_repo_code=0
    
    # 获取ISO文件
    find_os_yum
    
    # 判断是否配置了网络YUM源
    local repo_file_name=$(find_file_by_path /etc/yum.repos.d/ repo repo)
    if [ -z "${repo_file_name}" ]; then
        log_error "$(get_current_host_info)_[/etc/yum.repos.d/] *.repo file is not found." false
    else
        if [ -n "$(cat /etc/yum.repos.d/${repo_file_name} | grep "http://${is_om_machine}")" ]; then
            ret_code_mount=2
            log_info "$(get_current_host_info)_the yum network source is configured on the current node." false
        fi  
    fi
    
    # 如果配置网络源则不进行开机自动加载等其它项检查
    if [ "${ret_code_mount}" != "2" ]; then
        # 检查是否挂载YUM源
        if [ "$(df -Th | grep -o "iso9660")" != "iso9660" ]; then
            ret_code_mount="1"
        fi
        # 检查是否配置开机自启动
        local old_content=$(tail /etc/fstab)
        local modify_content="${sourcecode_dir}/${yum_iso_file_name} /${yum_install_path} iso9660 loop 0 0"
        if [[ "${old_content}" =~ "${modify_content}" ]]; then
            ret_code_auto_start="0"
        else
            ret_code_auto_start="1"
        fi
        ############### /etc/yum.repos.d/local.repo文件配置检查 ###############
        if [ "$(check_local_repo)" == "1" ]; then
            ret_repo_code=1
        fi 
    fi
    ret_info=(${ret_code_mount} ${ret_code_auto_start} ${ret_repo_code})
    echo ${ret_info[@]}
}

function check_yum_result() {
    echo -e ""
    echo -e "\033[33m==================[1]节点YUM源挂载检查结果================================\033[0m"
    return_msg=($(check_yum_server))
    if [ "${return_msg[0]}" == "2" ]; then
        echo -e "\033[33m==\033[0m\033[32m  当前节点YUM源已配置网络源                            [ √ ]\033[0m          \033[33m==\033[0m"
    else
        if [ "${return_msg[0]}" == "0" ]; then
        echo -e "\033[33m==\033[0m\033[32m  节点YUM源已挂载                                      [ √ ]\033[0m          \033[33m==\033[0m"
        else
            echo -e "\033[33m==\033[0m\033[31m  节点YUM源未挂载                                      [ X ]\033[0m          \033[33m==\033[0m"
        fi
        if [ "${return_msg[1]}" == "0" ]; then
            echo -e "\033[33m==\033[0m\033[32m  节点YUM源开机自动挂载已配置                          [ √ ]\033[0m          \033[33m==\033[0m"
        else
            echo -e "\033[33m==\033[0m\033[31m  节点YUM源开机自动挂载未配置                          [ X ]\033[0m          \033[33m==\033[0m"
        fi
        if [ "${return_msg[2]}" == "0" ]; then
            echo -e "\033[33m==\033[0m\033[32m  [/etc/yum.repos.d/local.repo]文件配置检查正常        [ √ ]\033[0m          \033[33m==\033[0m"
        else
            echo -e "\033[33m==\033[0m\033[31m  [/etc/yum.repos.d/local.repo]文件配置检查异常        [ X ]\033[0m          \033[33m==\033[0m"
        fi  
    fi
    echo -e "\033[33m==================[1]节点YUM源挂载检查结果================================\033[0m"
}

# 挂载YUM源
function mount_yum_server() {
    # 查找获取YUM挂载的ISO文件
    find_os_yum
    if [ "${yum_iso_file_name}" == "" ]; then
        # 当前操作系统名称
        log_error "$(get_current_host_info)_[${sourcecode_dir}] yum iso file not found, local mounting is not supported." false
    else
        # 如果已挂载则先卸载（没有使用自动化挂载）
        # 目的是防止与自动化初始化脚本挂载方式不一致导致不可预知的问题
        if [ "$(df -h | grep -o /${yum_install_path})" != "" ]; then
            umount /${yum_install_path}/
        fi
        ############### 本地方式挂载 ###############
        # 1. 创建挂载路径
        if [ ! -d "/${yum_install_path}/" ]; then
            mkdir -m 755 -p /${yum_install_path}/
        fi
        # 2. 挂载YUM镜像
        mount -t iso9660 -o loop ${sourcecode_dir}/${yum_iso_file_name} /${yum_install_path} &>/dev/null
        # 3. 检查判断是否挂载成功
        if [ -z "$(df -h | grep -o /${yum_install_path})" ]; then
            log_error "$(get_current_host_info)_[${sourcecode_dir}] mounting failed, check the mounting process." false
        else
            local current_date=$(date '+%Y%m%d%H%M%S')
            log_info "the yum image source is mounted successfully, the yum configuration starts..." false
            log_info "configuring cd-rom mounting for automatic startup upon system startup." false
            log_info "backing up [/etc/fstab] file to [/etc/fstab.${current_date}.bak]." false
            # 4.备份开机自启动文件
            cp /etc/fstab /etc/fstab.${current_date}.bak
            # ############### 5.设置配置开机自动挂载 ###############
            # 5.1判断是否存在之前已挂载的YUM自启动配置内容
            local line_nums=($(echo -n $(cat /etc/fstab | grep -n "iso /${yum_install_path} iso9660 loop 0 0" | cut -d ":" -f 1)))
            if [ -n "${line_nums}" ]; then
                for (( i = 0; i < ${#line_nums[@]}; i++ )); do
                    # 5.2删除之前配置的自启动配置内容
                    sed -i "${line_nums[i]}d" /etc/fstab
                done
                # 5.3删除多余空白行
                sed -i /^[[:space:]]*$/d /etc/fstab
            fi
            if [[ "$(tail /etc/fstab)" =~ "${sourcecode_dir}/${yum_iso_file_name} /${yum_install_path} iso9660 loop 0 0" ]]; then
                log_info "automatic mounting upon startup has been configured." false
            else
                # 5.4追加内容到配置文件中
                echo -ne "\n${sourcecode_dir}/${yum_iso_file_name} /${yum_install_path} iso9660 loop 0 0" >>/etc/fstab
            fi
            # 6. 重新加载fstab文件中的内容
            mount /${yum_install_path} &>/dev/null
            if [ ! -d "/etc/yum.repos.d/repo.bak/" ]; then
                mkdir -m 755 -p /etc/yum.repos.d/repo.bak/
            fi
            # 7. 备份旧的repo配置文件
            mv -f /etc/yum.repos.d/* /etc/yum.repos.d/repo.bak &>/dev/null
            echo -ne "[local]\nname=local\nbaseurl=file:///${yum_install_path}/\nenabled=1\ngpgcheck=0\n\n" >/etc/yum.repos.d/local.repo
            # 8. 清理和重新加载缓存
            yum clean all &>/dev/null && yum makecache &>/dev/null
            log_info "$(get_current_host_info)_node mounted successfully." false
        fi
    fi
}

# 当yum源安装配置完成后检查并安装基础命令
function basic_commands_install() {
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
                        yum install -y ${basic_commands[i]} &>/dev/null
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
                        yum install -y ${basic_commands[i]} &>/dev/null
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
                        yum localinstall -y *.rpm &>/dev/null
                        log_info "[${basic_commands[i]}] command installation succeeded." false
                    fi
                else
                    log_error "[${basic_commands[i]}] command cannot be found in the yum source." false  
                fi
            else
                yum install -y ${basic_commands[i]} &>/dev/null
                log_info "[${basic_commands[i]}] command installation succeeded." false
            fi
        else
            log_info "[${basic_commands[i]}] command does not need to be installed." false
        fi
    done
}

function mount_yum_result() {
    echo -e ""
    echo -e "\033[33m==================[1]节点YUM源挂载配置开始================================\033[0m"
    # 调用YUM挂载方法
    mount_yum_server
    basic_commands_install
    # 对YUM挂载进行检查
    return_msg=($(check_yum_server))
    if [ "${return_msg[0]}" == "2" ]; then
        echo -e "\033[33m==\033[0m\033[32m  当前节点YUM源已配置网络源                            [ √ ]\033[0m          \033[33m==\033[0m"
    else
        if [ "${return_msg[0]}" == "0" ]; then
        echo -e "\033[33m==\033[0m\033[32m  节点YUM源已挂载                                      [ √ ]\033[0m          \033[33m==\033[0m"
        else
            echo -e "\033[33m==\033[0m\033[31m  节点YUM源未挂载                                      [ X ]\033[0m          \033[33m==\033[0m"
        fi
        if [ "${return_msg[1]}" == "0" ]; then
            echo -e "\033[33m==\033[0m\033[32m  节点YUM源开机自动挂载已配置                          [ √ ]\033[0m          \033[33m==\033[0m"
        else
            echo -e "\033[33m==\033[0m\033[31m  节点YUM源开机自动挂载未配置                          [ X ]\033[0m          \033[33m==\033[0m"
        fi
        if [ "${return_msg[2]}" == "0" ]; then
            echo -e "\033[33m==\033[0m\033[32m  [/etc/yum.repos.d/local.repo]文件配置检查正常        [ √ ]\033[0m          \033[33m==\033[0m"
        else
            echo -e "\033[33m==\033[0m\033[31m  [/etc/yum.repos.d/local.repo]文件配置检查异常        [ X ]\033[0m          \033[33m==\033[0m"
        fi  
    fi
    echo -e "\033[33m==================[1]节点YUM源挂载配置开始================================\033[0m"
}

# 脚本执行合法性检查
function required_check() {
    # 运维节点OM配置检查
    if [ -z "${is_om_machine}" ]; then
        echo -e "\033[31m ip address of the om node is not configured, system exit.\033[0m"
        return 1
    fi
    # 查找挂载YUM源的ISO文件
    find_os_yum
    if [ "${yum_iso_file_name}" == "" ]; then
        echo -e "\033[31m [${sourcecode_dir}] directory yum iso file does not exist, system exit.\033[0m"
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
manual_script_action ${is_manual_script} ${is_open_debug} required_check check_yum_result mount_yum_result