#
# Copyright (c) Huawei Technologies Co., Ltd. 2022-2022. All rights reserved.
#
#!/usr/bin/env bash
######################################################################
# 脚本描述：一键安装配置基础项自动化脚本                                     #
# 注意事项：无                                                         #
######################################################################
# set -x

# 引用函数文件开始
root_dir=${1}
if [ "${root_dir}" == "opt" ]; then
    # 定义脚本文件、配置文件存放目录
    base_directory=/${root_dir}/hpcpilot/hpc_script
else
    # 定义脚本文件、配置文件存放目录
    base_directory=/${root_dir}/software/tools/hpc_script
fi
source ${base_directory}/common.sh ${root_dir}
source ${base_directory}/basic_script/cas_yum.sh false false ${root_dir} false
source ${base_directory}/basic_script/cas_ansible.sh false false ${root_dir} false
source ${base_directory}/basic_script/cac_hostname.sh false false ${root_dir} false
source ${base_directory}/basic_script/cac_selinux.sh false false ${root_dir} false
source ${base_directory}/basic_script/cac_firewall.sh false false ${root_dir} false
source ${base_directory}/basic_script/cac_ulimit.sh false false ${root_dir} false
source ${base_directory}/basic_script/cac_pass_free.sh false false ${root_dir} false
source ${base_directory}/basic_script/cas_mellanox.sh false false ${root_dir} false
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
    echo -e "\033[32m内核版本   :\033[0m   $(uname -r)"
    echo -e "\033[32m发行版本   :\033[0m   $(cat /etc/system-release)"
    echo -e "\033[32mIP 地址信息:\033[0m   $(get_current_host_ip)"
    echo -e "\033[32mCPU型号信息:\033[0m   $(dmidecode -s processor-version | tail -n1)"
    echo -e "\033[32mCPU个数    :\033[0m  $(lscpu | grep 'CPU(s)' | head -n1 | tr -s ' ' | cut -d : -f2)"
    echo -e "\033[32m内存信息   :\033[0m   $(free -h | grep Mem | tr -s ' ' : | cut -d : -f2)"
    echo -e "\033[32m当前时间   :\033[0m   $(date '+%Y-%m-%d %H:%M:%S')"
    echo -e "\033[33m=============================当前机器信息概览=============================\033[0m"
}

# 主函数 程序入口
function main() {
    # 当前机器信息概览
    current_machine_info
    # 计算节点YUM源挂载配置开始
    check_yum_result
    # ansible软件服务端配置检查
    check_setup_ansible_result
    # 修改所有节点hostname名称
    modify_hostname_result
    # 计算节点免密配置
    check_pass_free_result
    # 计算节点关闭selinux
    close_selinux_result
    # 关闭所有节点防火墙配置
    disable_firewall_result
    # 计算节点Mellanox网卡驱动安装
    install_mellanox_result
    # 所有节点配置最大进程数自动化脚本
    config_ulimit_result
    ###############运行日志路径提示###############
    view_log_path
}

main

exit_and_cleanENV 0
