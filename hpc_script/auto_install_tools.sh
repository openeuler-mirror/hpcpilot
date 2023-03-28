#
# Copyright (c) Huawei Technologies Co., Ltd. 2022-2022. All rights reserved.
#
#!/usr/bin/env bash
# 一键安装配置基础项自动化脚本

# 引用函数文件开始
root_dir=$(echo "$(pwd)" | awk '{split($1,arr,"/");print arr[2]}')
source /${root_dir}/software/tools/hpc_script/common.sh ${root_dir}
# 引用函数文件结束

# 所有脚本所在的根目录
base_script_dir=$(get_ini_value basic_conf basic_shared_directory /share)/software/tools/hpc_script

# 脚本执行合法性检查
function required_check() {
    # TODO 20230307_各自实现自己脚本的合法性检查,返回0（成功）或者1（失败）
    return 0
}

############### 主函数入口 ###############
function main() {
    required_check
    if [ "$?" == "1" ]; then
        exit 1
    fi
    # 手动选择需要执行的方法
    echo -e "\033[32m please select the script to execute.\033[0m"
    select action in "auto run all hpc tools scripts." "auto run configuration or installation basic script." "auto run check basic script." "auto run ntp ldap service installation script." "auto run benchmark tools installation script." "system exit."; do
        if [ "${action}" == "auto run all hpc tools scripts." ]; then
            ############### 基础配置检查和安装自动化脚本  ###############
            log_info "start to execute the basic configuration item automation script." false
            ${base_script_dir}/basic_script/auto_install_script.sh ${root_dir}
            ${base_script_dir}/basic_script/auto_check_script.sh ${root_dir}
            log_info "finish to execute the basic configuration item automation script." false
            
            ############### ntp ldap 服务安装配置自动化脚本  ###############
            log_info "start to execute the ntp ldap service installation and configuration automation script." false
            ${base_script_dir}/service_script/install_ntp_server.sh
            ${base_script_dir}/service_script/install_ntp_client.sh
            ${base_script_dir}/service_script/install_ldap_server.sh
            ${base_script_dir}/service_script/install_ldap_client.sh
            log_info "finish to execute the ntp ldap service installation and configuration automation script." false
            
            ############### benchmark测试工具安装配置自动化脚本  ###############
            log_info "start to execute the benchmark test tools installation and configuration automation script." false
            ${base_script_dir}/benchmark_script/compile_bisheng_hmpi_kml.sh
            ${base_script_dir}/benchmark_script/compile_osu.sh
            ${base_script_dir}/benchmark_script/compile_stream.sh
            ${base_script_dir}/benchmark_script/compile_hpl.sh ${root_dir}
            log_info "finish to execute the benchmark test tools installation and configuration automation script." false
        elif [ "${action}" == "auto run configuration or installation basic script." ]; then
            select action_basic in "installation and configuration all scripts." "yum installation and configuration scripts." "ansible installation and configuration scripts." "directory installation and configuration scripts." "hostname installation and configuration scripts." "pass_free installation and configuration scripts." "selinux installation and configuration scripts." "firewall installation and configuration scripts." "mellanox installation and configuration scripts." "cuda_toolkit installation and configuration scripts." "network installation and configuration scripts." "ulimit installation and configuration scripts." "nfs installation and configuration scripts." "users installation and configuration scripts." "system exit."; do
                if [ "${action_basic}" == "installation and configuration all scripts." ]; then
                    ${base_script_dir}/basic_script/auto_install_script.sh ${root_dir}
                elif [ "${action_basic}" == "yum installation and configuration scripts." ]; then
                    ${base_script_dir}/basic_script/cas_yum.sh true false ${root_dir}
                elif [ "${action_basic}" == "ansible installation and configuration scripts." ]; then
                    ${base_script_dir}/basic_script/cas_ansible.sh true false ${root_dir}
                elif [ "${action_basic}" == "directory installation and configuration scripts." ]; then
                    ${base_script_dir}/basic_script/cac_directory.sh true false ${root_dir}
                elif [ "${action_basic}" == "hostname installation and configuration scripts." ]; then
                    ${base_script_dir}/basic_script/cac_hostname.sh true false ${root_dir}
                elif [ "${action_basic}" == "pass_free installation and configuration scripts." ]; then
                    ${base_script_dir}/basic_script/cac_pass_free.sh true false ${root_dir}
                elif [ "${action_basic}" == "selinux installation and configuration scripts." ]; then
                    ${base_script_dir}/basic_script/cac_selinux.sh true false ${root_dir}
                elif [ "${action_basic}" == "firewall installation and configuration scripts." ]; then
                    ${base_script_dir}/basic_script/cac_firewall.sh true false ${root_dir}
                elif [ "${action_basic}" == "mellanox installation and configuration scripts." ]; then
                    ${base_script_dir}/basic_script/cas_mellanox.sh true false ${root_dir}
                elif [ "${action_basic}" == "cuda_toolkit installation and configuration scripts." ]; then
                    ${base_script_dir}/basic_script/cas_cuda.sh true false ${root_dir}
                elif [ "${action_basic}" == "network installation and configuration scripts." ]; then
                    ${base_script_dir}/basic_script/cac_ibtoroce.sh true false ${root_dir}
                elif [ "${action_basic}" == "ulimit installation and configuration scripts." ]; then
                    ${base_script_dir}/basic_script/cac_ulimit.sh true false ${root_dir}
                elif [ "${action_basic}" == "nfs installation and configuration scripts." ]; then
                    ${base_script_dir}/basic_script/cas_nfs.sh true false ${root_dir}
                elif [ "${action_basic}" == "users installation and configuration scripts." ]; then
                    ${base_script_dir}/basic_script/cac_users.sh true false ${root_dir}
                elif [ "${action_basic}" == "system exit." ]; then
                    exit 0
                else 
                    echo -e "\033[31m selected drop-down list does not match the defined, please select again.\033[0m"
                fi
            done
        elif [ "${action}" == "auto run check basic script." ]; then
            ${base_script_dir}/basic_script/auto_check_script.sh ${root_dir}
        elif [ "${action}" == "auto run ntp ldap service installation script." ]; then
            select action_ntp_ldap in "automatic ntp server and client script." "automatic ntp_server script." "automatic ntp_client script." "automatic ldap server and client script." "automatic ldap_server script." "automatic ldap_client script." "system exit."; do
                if [ "${action_ntp_ldap}" == "automatic ntp server and client script." ]; then
                    ${base_script_dir}/service_script/install_ntp_server.sh ${root_dir}
                    ${base_script_dir}/service_script/install_ntp_client.sh ${root_dir}
                elif [ "${action_ntp_ldap}" == "automatic ntp_server script." ]; then
                    ${base_script_dir}/service_script/install_ntp_server.sh ${root_dir}
                elif [ "${action_ntp_ldap}" == "automatic ntp_client script." ]; then
                    ${base_script_dir}/service_script/install_ntp_client.sh ${root_dir}
                elif [ "${action_ntp_ldap}" == "automatic ldap server and client script." ]; then
                    ${base_script_dir}/service_script/install_ldap_server.sh
                    ${base_script_dir}/service_script/install_ldap_client.sh ${root_dir}
                elif [ "${action_ntp_ldap}" == "automatic ldap_server script." ]; then
                    ${base_script_dir}/service_script/install_ldap_server.sh
                elif [ "${action_ntp_ldap}" == "automatic ldap_client script." ]; then
                    ${base_script_dir}/service_script/install_ldap_client.sh ${root_dir}
                elif [ "${action_ntp_ldap}" == "system exit." ]; then
                    exit 0
                else 
                    echo -e "\033[31m selected drop-down list does not match the defined, please select again.\033[0m"
                fi
            done
        elif [ "${action}" == "auto run benchmark tools installation script." ]; then
            select action_benchmark in "automatic benchmark all script." "automatic bisheng_hmpi_kml script." "automatic osu script." "automatic stream script." "automatic hpl script." "system exit."; do
                if [ "${action_benchmark}" == "automatic benchmark all script." ]; then
                    ${base_script_dir}/benchmark_script/compile_bisheng_hmpi_kml.sh
                    ${base_script_dir}/benchmark_script/compile_osu.sh
                    ${base_script_dir}/benchmark_script/compile_stream.sh
                    ${base_script_dir}/benchmark_script/compile_hpl.sh
                elif [ "${action_benchmark}" == "automatic bisheng_hmpi_kml script." ]; then
                    ${base_script_dir}/benchmark_script/compile_bisheng_hmpi_kml.sh
                elif [ "${action_benchmark}" == "automatic osu script." ]; then
                    ${base_script_dir}/benchmark_script/compile_osu.sh
                elif [ "${action_benchmark}" == "automatic stream script." ]; then
                    ${base_script_dir}/benchmark_script/compile_stream.sh
                elif [ "${action_benchmark}" == "automatic hpl script." ]; then
                    ${base_script_dir}/benchmark_script/compile_hpl.sh
                elif [ "${action_benchmark}" == "system exit." ]; then
                    exit 0
                else 
                    echo -e "\033[31m selected drop-down list does not match the defined, please select again.\033[0m"
                fi
            done
        elif [ "${action}" == "system exit." ]; then
            exit 0
        else
            echo -e "\033[31m selected drop-down list does not match the defined, please select again.\033[0m"
        fi
        ###############运行日志路径提示###############
        view_log_path
        ###############运行日志路径提示###############
    done
}

main

exit 0
