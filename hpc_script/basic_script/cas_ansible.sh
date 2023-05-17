#
# Copyright (c) Huawei Technologies Co., Ltd. 2022-2022. All rights reserved.
#
#!/usr/bin/env bash
######################################################################
# 脚本描述：安装ANSIBLE自动化配置管理工具自动化脚本                           #
# 注意事项：只在运维节点安装ANSIBLE                                       #
######################################################################
# set -x

# 引用公共函数文件开始
if [ "${3}" == "opt" ]; then
    # 定义脚本文件、配置文件存放目录
    base_directory=/${3}/hpcpilot/hpc_script
    # 依赖软件存放路径[/opt/hpcpilot/sourcecode]
    sourcecode_dir=/${3}/hpcpilot/sourcecode
else
    # 定义脚本文件、配置文件存放目录
    base_directory=/${3}/software/tools/hpc_script
    sourcecode_dir=/${3}/software/sourcecode
fi
source ${base_directory}/common.sh ${3}
# 引用公共函数文件结束

# 当前主机IP地址
current_ip_addr=$(get_current_host_ip)
# ansible版本号
ansible_version=""

# 检查ansible安装配置是否OK
function check_setup_ansible() {
    local ret_install_code="0"
    local ret_cfg_code="0"
    local ret_host_code="0"
    local is_install_succeed=$(rpm -qa ansible)
    if [ -n "$(echo "${current_ip_addr}" | grep "${om_machine_ip}")" ]; then
        if [ "${is_install_succeed}" == "" ]; then
            ret_install_code="1"
            echo ${ret_install_code}
        else
            # 检查ansible.cfg文件配置
            local result=$(cat /etc/ansible/ansible.cfg | grep "#host_key_checking")
            if [ "${result}" != "" ]; then
                ret_cfg_code="1"
            fi
            # 检查host文件配置是否存在
            if [ "$(is_file_exist /etc/ansible/hosts)" == "1" ]; then
                ret_host_code="1"
            fi
            # 获取ansible版本号
            ansible_version=$(ansible --version | awk '{print $2}'  | sed -n '1P')
            local ret_info=(${ret_install_code} ${ret_cfg_code} ${ret_host_code})
            echo ${ret_info[@]}  
        fi
    else
        ret_install_code="0"
        echo ${ret_install_code}
    fi
}

# 检查ansible安装配置是否OK打印输出
function check_setup_ansible_result() {
    echo -e ""
    echo -e "\033[33m==================[2]ANSIBLE安装检查结果==================================\033[0m"
    local return_msg=($(check_setup_ansible))
    if [ -n "$(echo "${current_ip_addr}" | grep "${om_machine_ip}")" ]; then
        # 运维节点检查结果显示
        if [ "${return_msg[0]}" == "0" ]; then
            echo -e "\033[33m==\033[0m\033[32m  ANSIBLE安装检查结果正常                              [ √ ]\033[0m          \033[33m==\033[0m"
            echo -e "\033[33m==\033[0m\033[32m  ANSIBLE软件当前版本为：$(ansible --version | awk '{print $2}'  | sed -n '1P')\033[0m                                        \033[33m==\033[0m"
            if [ "${return_msg[1]}" == "0" ]; then
                echo -e "\033[33m==\033[0m\033[32m  [/etc/ansible/ansible.cfg]文件配置正确               [ √ ]\033[0m          \033[33m==\033[0m"
            else
                echo -e "\033[33m==\033[0m\033[31m  [/etc/ansible/ansible.cfg]文件未配置或配置不正确     [ X ]\033[0m          \033[33m==\033[0m"
            fi
            if [ "${return_msg[2]}" == "0" ]; then
                echo -e "\033[33m==\033[0m\033[32m  [/etc/ansible/hosts]文件配置正确                     [ √ ]\033[0m          \033[33m==\033[0m"
            else
                echo -e "\033[33m==\033[0m\033[31m  [/etc/ansible/hosts]文件未配置或配置不正确           [ X ]\033[0m          \033[33m==\033[0m"
            fi
        else
            echo -e "\033[33m==\033[0m\033[31m  ANSIBLE软件当前未安装                                [ X ]\033[0m          \033[33m==\033[0m"
        fi  
    else
        # 非运维节点
        echo -e "\033[33m==\033[0m\033[32m  非运维节点无需安装ANSIBLE软件                        [ √ ]\033[0m          \033[33m==\033[0m"
    fi
    echo -e "\033[33m==================[2]ANSIBLE安装检查结果==================================\033[0m"
}

# 检查ansible文件是否存在
# 判断依据是如果文件名包含ansible且后缀名为.rpm即为当前需要安装的ansible文件
# 或者文件名以ansible_操作系统英文名称开头的文件即为当前需要安装的ansible文件
# 操作系统前缀名称，比如：CentOS、openEuler、Kylin
# 返回值为""不存在，否则返回ansible文件名
function find_ansible_file() {
    local ansible_file_name=""
    # 当前操作系统名称
    local current_os_info=($(cat /etc/system-release))
    cd ${sourcecode_dir}/ansible/
    local files=$(ls ${sourcecode_dir}/ansible/)
    for file_name in ${files}; do
        if [[ "${file_name}" =~ ^"ansible_${current_os_info[0]}"* ]]; then
            ansible_file_name=${file_name}
            break
        fi
        if [[ "${file_name}" =~ "ansible" ]] && [ "${file_name##*.}" == "rpm" ]; then
            ansible_file_name=${file_name}
            break
        fi
    done
    echo ${ansible_file_name}
}

# 安装配置ansible
function setup_and_config_ansible() {
    # 判断当前机器是否是运维节点
    local ansible_file_name=""
    if [ -n "$(echo "${current_ip_addr}" | grep "${om_machine_ip}")" ]; then
        if [ "$(rpm -qa ansible)" != "" ]; then
            log_info "Ansible has been installed and does not need to be installed again." true
        else
            # 安装ANSIBLE
            if [ "$(yum list | grep -F ansible)" == "" ]; then
                # 使用本地安装方式安装
                cd ${sourcecode_dir}/ansible/
                if [ "$(find_ansible_file)" != "" ]; then
                    # 目前本地安装支持 1.麒麟V10_ARM64版本、2.CENTOS7.6_ARM64版本 2.CENTOS8.2_ARM64版本
                    yum localinstall -y *.rpm >> ${operation_log_path}/access_all.log 2>&1
                    if [ -n "$(cat /etc/system-release) | grep 'CentOS Linux release 8.2.2004 (Core)'" ]; then
                        ansible-config init --disabled -t all > ansible.cfg
                    fi
                else
                    log_error "[${sourcecode_dir}/ansible/] ansible files doesn't exist." true
                fi
            else
                # 使用YUM源安装，当前只适用欧拉系统
                yum install -y ansible >> ${operation_log_path}/access_all.log 2>&1
            fi
            # 检查安装是否成功
            if [ "$(ansible --version)" != "" ]; then
                ansible_version=$(ansible --version | awk '{print $2}'  | sed -n '1P')
                log_info "Ansible service installation succeeded." true
            fi
            # 找到host_key_checking = False取消注释。该步骤为取消主机间初次ssh跳转的人机交互。
            remove_match_line_symbol /etc/ansible/ansible.cfg host_key_checking
        fi
    fi
}

# ANSIBLE安装部署结果输出打印
function setup_and_config_ansible_result() {
    echo -e ""
    echo -e "\033[33m==================[2]ANSIBLE安装部署开始==================================\033[0m"
    # 调用安装配置ANSIBLE方法
    setup_and_config_ansible
    # 刷新/etc/hosts和/etc/ansible/hosts
    create_ansible_hosts
    create_etc_hosts
    # 调用ANSIBLE检查的方法
    check_setup_ansible_result
}

# 脚本执行合法性检查
function required_check() {
    # 运维节点OM配置检查
    if [ -z "${om_machine_ip}" ]; then
        log_error "Ip address of O&M node is not configured, please check." true
        return 1
    fi
    # 检查ANSIBLE是否可以安装
    if [ -n "$(echo "${current_ip_addr}" | grep "${om_machine_ip}")" ]; then
        if [ $(is_file_exist ${hostname_file}) == "1" ]; then
            log_error "[${hostname_file}] file doesn't exist, please check." true
            return 1
        fi
        if [ "$(rpm -qa ansible)" == "" ]; then
            yum list 1>/dev/null 2>/dev/null
            # 如果未配置yum源不做ansible安装文件检查
            if [ $? -eq 1 ]; then
                return 0
            fi
            if [ "$(yum list | grep -F ansible)" == "" ]; then
                # 使用本地安装方式安装(检查本地ANSIBLE文件是否存在)
                if [ "$(find_ansible_file)" == "" ]; then
                    log_error "[${sourcecode_dir}/ansible/] ansible installation files doesn't exist, please check." true
                    result 1
                fi
            fi
        fi
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
manual_script_action ${is_manual_script} ${is_open_debug} required_check check_setup_ansible_result setup_and_config_ansible_result ${4}