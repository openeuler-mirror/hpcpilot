#
# Copyright (c) Huawei Technologies Co., Ltd. 2022-2022. All rights reserved.
#

#!/usr/bin/env bash
# 进行所有基础配置检查自动化脚本
#set -x
# 引用函数文件开始
# root_dir=$(echo "$(pwd)" | awk '{split($1,arr,"/");print arr[2]}')
root_dir=${1}
if [ -z "${root_dir}" ]; then
    root_dir=share
fi
source /${root_dir}/software/tools/hpc_script/common.sh ${root_dir}
source /${root_dir}/software/tools/hpc_script/basic_script/cac_directory.sh false false ${root_dir}
source /${root_dir}/software/tools/hpc_script/basic_script/cas_yum.sh false false ${root_dir}
source /${root_dir}/software/tools/hpc_script/basic_script/cas_ansible.sh false false ${root_dir}
source /${root_dir}/software/tools/hpc_script/basic_script/cac_hostname.sh false false ${root_dir}
source /${root_dir}/software/tools/hpc_script/basic_script/cac_selinux.sh false false ${root_dir}
source /${root_dir}/software/tools/hpc_script/basic_script/cac_firewall.sh false false ${root_dir}
source /${root_dir}/software/tools/hpc_script/basic_script/cac_ulimit.sh false false ${root_dir}
source /${root_dir}/software/tools/hpc_script/basic_script/cac_pass_free.sh false false ${root_dir}
source /${root_dir}/software/tools/hpc_script/basic_script/cas_mellanox.sh false false ${root_dir}
source /${root_dir}/software/tools/hpc_script/basic_script/cas_cuda.sh false false ${root_dir}
source /${root_dir}/software/tools/hpc_script/basic_script/cac_ibtoroce.sh false false ${root_dir}
source /${root_dir}/software/tools/hpc_script/basic_script/cas_nfs.sh false false ${root_dir}
source /${root_dir}/software/tools/hpc_script/basic_script/cac_users.sh false false ${root_dir}
# 引用函数文件结束

function basic_check_items_msg() {
    echo -e ""
    echo -e "\033[33m=========================基础环境配置待检查项列表=========================\033[0m"
    echo -e "\033[33m==   1. 请使用root用户执行该脚本                                        ==\033[0m"
    echo -e "\033[33m==   2. 详细执行、错误、警告信息请查看日志[${global_operation_log_path}]           ==\033[0m"
    echo -e "\033[33m==   3. 运行前请严格按照安装文档要求执行                                ==\033[0m"
    echo -e "\033[33m==   4. 检查日期:$(date "$(get_ini_value common_global_conf common_date_format_002)")                                    ==\033[0m"
    echo -e "\033[33m=========================基础环境配置待检查项列表=========================\033[0m"
    
    echo -e "************\033[32m[1]\033[0m  节点YUM源挂载检查                       \033[32m[ √ ]\033[0m************"
    echo -e "************\033[32m[2]\033[0m  ANSIBLE安装检查                         \033[32m[ √ ]\033[0m************"
    echo -e "************\033[32m[3]\033[0m  计算节点目录规划检查                    \033[32m[ √ ]\033[0m************"
    echo -e "************\033[32m[4]\033[0m  计算节点名称规划检查                    \033[32m[ √ ]\033[0m************"
    echo -e "************\033[32m[5]\033[0m  计算节点免密配置检查                    \033[32m[ √ ]\033[0m************"
    echo -e "************\033[32m[6]\033[0m  计算节点关闭selinux检查                 \033[32m[ √ ]\033[0m************"
    echo -e "************\033[32m[7]\033[0m  计算节点关闭防火墙检查                  \033[32m[ √ ]\033[0m************"
    echo -e "************\033[32m[8]\033[0m  计算节点Mellanox网卡驱动安装检查        \033[32m[ √ ]\033[0m************"
    echo -e "************\033[32m[9]\033[0m  计算节点CUDAToolkit安装检查             \033[32m[ √ ]\033[0m************"
    echo -e "************\033[32m[10]\033[0m 计算节点网络配置检查                    \033[32m[ √ ]\033[0m************"
    echo -e "************\033[32m[11]\033[0m 计算节点Ulimit配置检查                  \033[32m[ √ ]\033[0m************"
    echo -e "************\033[32m[12]\033[0m 计算节点挂载配置存储NFS检查             \033[32m[ √ ]\033[0m************"
    echo -e "************\033[32m[13]\033[0m 计算节点批量创建用户检查                \033[32m[ √ ]\033[0m************"
}

function current_machine_info() {
    echo -e "\033[33m=============================当前机器信息概览=============================\033[0m"
    echo -e "\033[32m主机名     :\033[0m   $(hostname)"
    echo -e "\033[32m当前用户   :\033[0m   $(whoami)"
    local vserver=$(dmidecode -s system-product-name)
    if [[ "${vserver}" =~ "Virtual" ]] ; then
        echo -e "\033[32m机器类型   :\033[0m   虚拟机"
    else
        echo -e "\033[32m机器类型   :\033[0m   物理机"
    fi
    echo -e "\033[32m业务分组   :\033[0m   $(get_current_host_group)"
    # echo -e "\033[32m在线用户:\033[0m      $(w | cut -d ' ' -f1 | grep -v USER | xargs -n1 | sed -e 's/\r//g')"
    echo -e "\033[32m内核版本   :\033[0m   $(uname -r)"
    echo -e "\033[32m发行版本   :\033[0m   $(cat /etc/system-release)"
    echo -e "\033[32mIP 地址信息:\033[0m   $(get_current_host_ip)"
    echo -e "\033[32mCPU型号信息:\033[0m   $(dmidecode -s processor-version | tail -n1)"
    #machine_info="${machine_info}CPU型号信息:$(cat /proc/cpuinfo | grep "model name" | cut -d: -f2 | head -1)\n"
    echo -e "\033[32mCPU个数    :\033[0m  $(lscpu | grep 'CPU(s)' | head -n1 | tr -s ' ' | cut -d : -f2)"
    echo -e "\033[32m内存信息   :\033[0m   $(free -h | grep Mem | tr -s ' ' : | cut -d : -f2)"
    # echo -e "\033[32m磁盘信息:\033[0m      $(df -Ph | sed s/%//g | awk '{ if($5 > 0) print $0;}')"
    echo -e "\033[32m当前时间   :\033[0m   $(date "$(get_ini_value common_global_conf common_date_format_002)")"
    echo -e "\033[33m=============================当前机器信息概览=============================\033[0m"
}

# 主函数 程序入口
function main() {
     # 当前机器信息概览
     current_machine_info
     # 检查提示项
     basic_check_items_msg
     # [1]yum源安装配置检查
     check_yum_result
     # [2]ansible软件服务端配置检查
     check_setup_ansible_result
     # [3]业务目录是否配置正常
     check_directory_result
     # [4]主机名称配置检查
     check_hostname_result
     # [5]免密配置检查
     check_pass_free_result
     # [6]计算节点关闭selinux检查
     check_selinux_result
     # [7]关闭防火墙配置检查    
     check_firewall_result
     # [8]节点Mallanox网卡驱动安装检查
     check_mellanox_result
     # [9]节点CUDAToolkit安装检查
     check_cuda_result
     # [10]计算节点网络配置检查
     check_config_result
     # [11]计算节点ulimit配置检查
     check_ulimit_result
     # [12] 计算节点挂载配置存储NFS检查
     check_nfs_result
     # [13] 计算节点批量创建用户检查
     check_users_result
     ###############运行日志路径提示###############
     view_log_path
     
    ###############使用ANSIBLE执行其它节点###############
    if [ "$(rpm -qa ansible)" == "" ]; then
        log_error "$(get_current_host_info)_ansible is not installed or fails to be installed." false
    else
        
        # 如果是运维节点使用ansible执行其它节点
        if [ "$(get_ini_value basic_conf basic_om_master_ip)" == "$(get_current_host_ip)" ]; then
            ansible -i /etc/ansible/hosts all -m shell -a "/${root_dir}/software/tools/hpc_script/basic_script/auto_check_script.sh ${root_dir}"  
        fi  
    fi
    ###############使用ANSIBLE执行其它节点###############
}

main

exit 0
