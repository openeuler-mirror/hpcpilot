#!/usr/bin/env bash
# 一键安装配置基础项自动化脚本

# 引用函数文件开始
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
    # [1]节点YUM源挂载配置开始
    mount_yum_result
    # [2]ANSIBLE安装部署
    setup_and_config_ansible_result
    # [3]创建业务规划目录
    create_directory_result
    # [4]计算节点名称规划设置
    modify_hostname_result
    # [5]计算节点免密配置
    config_pass_free_result
    # [6]计算节点关闭selinux
    close_selinux_result
    # [7]关闭防火墙配置
    disable_firewall_result
    # [8]计算节点Mellanox网卡驱动安装
    install_mellanox_result
    # [9]计算节点CUDAToolkit安装配置
    install_cuda_result
    # [10]计算节点网络配置
    edit_config_result
    # [11]计算节点ulimit配置
    config_ulimit_result
    # [13]计算节点批量创建用户开始
    create_users_result
    ###############运行日志路径提示###############
    view_log_path
    
    ###############使用ANSIBLE执行其它节点###############
    if [ "$(rpm -qa ansible)" == "" ]; then
        log_error "$(get_current_host_info)_ansible is not installed or fails to be installed." false
    else
        # 如果是运维节点使用ansible执行其它节点
        if [ "$(get_ini_value basic_conf basic_om_master_ip)" == "$(get_current_host_ip)" ]; then
            ansible -i /etc/ansible/hosts all -m shell -a "/${root_dir}/software/tools/hpc_script/basic_script/auto_install_script.sh ${root_dir}"
            # 重启除运维节点所有节点
            while true 
            do
                read -r -p "do you need to restart immediately? [y/n]" input
                if [ -n "$(echo "YES Y" | grep -w -i ${input})" ]; then
                    log_info "$(get_current_host_info)_restarting all node machines..." false
                    ansible -i /etc/ansible/hosts all -m shell -a 'reboot'
                    break
                elif [ -n "$(echo "NO N" | grep -w -i ${input})" ]; then
                    log_info "$(get_current_host_info)_do not restart all nodes." false
                    break
                else
                    echo "invalid input parameter [${input}], please enter again [y/n]."
                fi    
            done 
        fi
    fi
    ###############使用ANSIBLE执行其它节点###############
}

main

exit 0
