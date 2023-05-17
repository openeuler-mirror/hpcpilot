#
# Copyright (c) Huawei Technologies Co., Ltd. 2022-2022. All rights reserved.
#
#!/usr/bin/env bash
# 基础项安装配置系统初始化脚本，主要用来初始化一键安装脚本准备工作
# 挂载运维节点YUM源、安装ANSIBLE软件、本地ssh-key、本地/etc/hosts

# 引用函数文件开始
root_dir=${1}
if [ "${root_dir}" == "opt" ]; then
    # 定义脚本文件、配置文件存放目录
    base_directory=/${root_dir}/hpcpilot/hpc_script
    # 依赖软件存放路径[/opt/hpcpilot/sourcecode]
    sourcecode_dir=/${root_dir}/hpcpilot/sourcecode
else
    # 定义脚本文件、配置文件存放目录
    base_directory=/${root_dir}/software/tools/hpc_script
    sourcecode_dir=/${root_dir}/software/sourcecode
fi
source ${base_directory}/common.sh ${root_dir}
source ${base_directory}/basic_script/cas_yum.sh false false ${root_dir} false
source ${base_directory}/basic_script/cas_ansible.sh false false ${root_dir} false
source ${base_directory}/basic_script/cac_pass_free.sh false false ${root_dir} false
# 引用函数文件结束

# 对初始化脚本所需文件进行验证
function init_verify() {
    local error_flag=0
    # 获取当前主机IP地址（无法使用ifconfig命令情况下）
    local current_ip_addr=$(ip addr | awk '/^[0-9]+: / {}; /inet.*global/ {print gensub(/(.*)\/(.*)/, "\\1", "g", $2)}')
    if [ -z "$(echo "${current_ip_addr}" | grep "${om_machine_ip}")" ]; then
        log_error "Current script needs to be executed on the om node, system exit." true
        return 1
    fi
    # 当前操作系统名称
    local current_os_info=($(cat /etc/system-release))
    ############### 遍历sourcecode文件夹中依赖软件或软件包都准备齐全 ###############
    if [ ! -d "${sourcecode_dir}" ]; then
         echo -e "\033[49;31m current running scripts [${0}] does not [${sourcecode_dir}].\033[0m"
         return 1
    fi
    
    local current_os_yum_iso
    local files=$(ls ${sourcecode_dir})
    if [ -n "${files}" ]; then
        for file_name in ${files}; do
            if [ "${file_name##*.}" == "iso" ]; then
                if [[ "${file_name}" =~ "${current_os_info[0]}" ]]; then
                    current_os_yum_iso=${file_name}
                fi
            fi
        done
    else
        echo -e "\033[31m [${sourcecode_dir}] directory is empty, operation cannot be performed.\033[0m"
        return 1
    fi
    # 检查当前操作系统类型的ISO文件是否找到
    if [ "${current_os_yum_iso}" == "" ]; then
        echo -e "\033[49;31m [${sourcecode_dir}] directory yum iso file does not exist.\033[0m"
        error_flag=1
    fi
    if [ "$(rpm -qa ansible)" == "" ]; then
        yum list 1>/dev/null 2>/dev/null
        # 如果未配置yum源不做ansible安装文件检查
        if [ $? -eq 0 ]; then
            if [ "$(yum list | grep -F ansible)" == "" ]; then
                # 使用本地安装方式安装(检查本地ANSIBLE文件是否存在)
                if [ "$(find_file_by_path ${sourcecode_dir}/ansible ansible rpm)" == "" ]; then
                    echo -e "\033[31m [${sourcecode_dir}/ansible] ansible installation files does not exist, system exit.\033[0m"
                    error_flag=1
                fi
            fi
        fi
    fi
    if [ ! -f "${base_directory}/hostname.csv" ]; then
        echo -e "\033[49;31m [${base_directory}/hostname.csv] file does not exist.\033[0m"
        error_flag=1
    fi
    if [ ! -f "${base_directory}/setting.ini" ]; then
        echo -e "\033[49;31m [${base_directory}/setting.ini] file does not exist.\033[0m"
        error_flag=1
    fi
    if [ ! -f "${base_directory}/users.json" ]; then
        echo -e "\033[49;31m [${base_directory}/users.json] file does not exist.\033[0m"
        error_flag=1
    fi
    if [ "${error_flag}" == "1" ]; then
        return 1
    fi
}

# 主函数入口
function main() {
    # 检查校验执行初始化脚本的合法性
    init_verify
    if [ "$?" == "1" ]; then
        exit_and_cleanENV 1
    fi
    # 检查是否是扩容操作
    if [ "$(check_run_expansion)" == "0" ]; then
        # 在运维节点挂载本地YUM源
        echo -e "\033[32m =============== begin to mount yum source to manage node ===============\033[0m"
        mount_local_yum ${sourcecode_dir} ${base_directory}
        basic_commands_install
        echo -e "\033[32m =============== finish to mount yum source to manage node ===============\033[0m"
        # 在运维节点安装ANSIBLE软件
        echo -e "\033[32m =============== begin to setup and config ansible ===============\033[0m"
        setup_and_config_ansible
        echo -e "\033[32m =============== finish to setup and config ansible ===============\033[0m"
        # 在运维节点执行本地ssh-key
        echo -e "\033[32m =============== begin to create local sshkey ===============\033[0m"
        create_local_sshkey
        echo -e "\033[32m =============== finish to create local sshkey ===============\033[0m"  
    fi
    # 刷新/etc/hosts和/etc/ansible/hosts
    echo -e "\033[32m =============== begin to create /etc/hosts and /etc/ansible/hosts to manage node ===============\033[0m"
    create_ansible_hosts
    create_etc_hosts
    echo -e "\033[32m =============== finish to create /etc/hosts and /etc/ansible/hosts to manage node ===============\033[0m"
}

main
