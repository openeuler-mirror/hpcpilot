#
# Copyright (c) Huawei Technologies Co., Ltd. 2022-2022. All rights reserved.
#
#!/usr/bin/env bash
######################################################################
# 脚本描述：集成所有安装配置检查自动化脚本（程序总入口）                         #
# 注意事项：无                                                          #
######################################################################
# set -x

# 引用函数文件开始
root_dir=$(echo "$(pwd)" | awk '{split($1,arr,"/");print arr[2]}')
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

# 脚本退出或异常中断处理
trap "trap_exit_ctrlC" EXIT

# 脚本退出或异常中断处理，清理密码和安装日志
function trap_exit_ctrlC() {
    # 获取退出状态必须放在函数的第一行
    local exit_status=$?
    log_warn "Abnormal interruption [CTRL+C] exit." false
	# 清理配置文件涉及到的密码
    clean_pw_all
    # 清理ANSIBLE运行日志
    if [ -d "${ansible_log_path}" ] && [ "${ansible_log_path}" != "/" ]; then
        rm -rf ${ansible_log_path}/*
    fi
    # 清理删除hpcpilot.pid
    if [ -f "/var/log/hpcpilot.pid" ]; then
        rm -rf /var/log/hpcpilot.pid
    fi
    log_warn "Password is cleared, config password when you run scripts again." true
}

# 清除所有节点密码
function clean_pw_all() {
    # 清理配置文件涉及到的密码
    while IFS= read -r line; do
        if grep -q -e "_passwor" <<< "${line}"; then
            item=$(echo "$line" | awk -F= '{print $1}')
            ansible all -m shell -a "sed -i 's/${item}.*/${item}=/g' ${ini_file}" > /dev/null 2>&1
        fi
    done < ${ini_file}
}

# 引用函数文件结束
# 服务器节点ROOT登录密码
root_login_password=$(get_ini_value common_global_conf common_sys_root_password)
# 并发执行判断（不同窗口不能同时执行脚本[并发]）
check_concurrent_execution
if [ "$?" == "1" ]; then
    log_warn "Scripts is being executed and does not need to be repeated." true
    exit 0
fi

# 获取当前主机IP地址（无法使用ifconfig命令情况下）
current_ip_addr=$(ip addr | awk '/^[0-9]+: / {}; /inet.*global/ {print gensub(/(.*)\/(.*)/, "\\1", "g", $2)}')
# 判断是否扩容操作 
if [ "$(check_run_expansion)" == "1" ]; then
    ansible_group_name=expansion
else
    ansible_group_name=all
fi

# 批量执行脚本
# 参数${1}为基础配置项脚本名称
function batch_run_scripts() {
    # 检查sshpass服务是否安装
    if [ "$(rpm -qa sshpass)" == "" ]; then
        log_error "SSHPASS service is not installed, scripts cannot be run." true
        return
    fi
    # 检查hostname.csv配置文件是否存在
    if [ $(is_file_exist ${hostname_file}) == "1" ]; then
        log_error "[${hostname_file}] file doesn't exist, scripts cannot be run." true
        return
    fi
    
    local unconnected_ip
    # tail -n +2 从第二行开始读取数据，第一行为标题行
    for line in $(cat ${hostname_file} | tail -n +2); do
        # 检查判断字符串长度是否为0
        if [ -n "${line}" ]; then
            local host_ip=$(echo ${line} | awk -F "," '{print $1}')
            local host_name=$(echo ${line} | awk -F "," '{print $2}')
            log_tips "" true
            log_tips "===============current host [${host_ip}_${host_name}] run script begin===============" true
            if [ -n "$(echo "$(get_current_host_ip)" | grep "${host_ip}")" ]; then
                # 如果是当前机器使用本地模式执行
                ${base_directory}/basic_script/${1} false false ${root_dir} true
            else
                # 检查主机的连通性
                ping -c 1 ${host_ip} &>/dev/null
                if [ $? -eq 0 ]; then
                    # 执行远程脚本
                    local result=$(sshpass -f ${base_directory}/.sshpass ssh root@${host_ip} "sh ${base_directory}/basic_script/${1} false false ${root_dir} true")
                    log_tips "===============[${1}] script execution result:===============" true
                    log_tips " ${result} " true
                else
                    # 未联通的主机
                    unconnected_ip="${unconnected_ip}\n${host_ip}"
                fi
            fi
            log_tips "===============current host [${host_ip}_${host_name}] run script finish===============" true
        fi
    done
    if [ -n "${unconnected_ip}" ]; then
        log_error "Not connected hosts ip are as follows：${unconnected_ip}" true
    fi
}

# 校验LDAP服务端参数合法性
# 校验通过返回值为0 不通过返回值为1
function valid_ldap_server() {
    local error_tag=0
    local ldap_server_ip=$(get_ini_value service_conf master_ldap_server_ip)
    local ldap_slave_ip=$(get_ini_value service_conf slave_ldap_server_ip)
    local ldap_virtual_ip=$(get_ini_value service_conf virtual_ldap_server_ip)
    if [ "$(rpm -qa ansible)" == "" ]; then
        log_error "Ansible is not installed or fails to be installed." true
        error_tag=1
    fi
    if [ -z "${ldap_server_ip}" ] || [ "$(valid_ip_address ${ldap_server_ip})" == "1" ]; then
        if [ -z "${ldap_server_ip}" ]; then
            log_error "Ip address of the ldap server is empty." true
        else
            log_error "Ip address of the ldap server is invalid, ldap_server_ip = ${ldap_server_ip}" true
        fi
        error_tag=1
    fi
    if [ -n "${ldap_slave_ip}" ]; then
        if [ "$(valid_ip_address ${ldap_slave_ip})" == "1" ]; then
            log_error "Ip address of the ldap slave is invalid, ldap_slave_ip = ${ldap_slave_ip}" true
            error_tag=1
        else
            if [ -z "${ldap_virtual_ip}" ] || [ "$(valid_ip_address ${ldap_virtual_ip})" == "1" ]; then
                if [ -z "${ldap_virtual_ip}" ]; then
                    log_error "Ip address of the ldap virtual is empty." true
                else
                    log_error "Ip address of the ldap virtual is invalid, ldap_virtual_ip = ${ldap_virtual_ip}" true
                fi
                error_tag=1
            fi
        fi
    fi
    return ${error_tag}
}

# 校验LDAP客户端参数合法性
# 校验通过返回值为0 不通过返回值为1
function valid_ldap_client() {
    local error_tag=0
    local ldap_server_ip=$(get_ini_value service_conf master_ldap_server_ip)
    if [ -z "${ldap_server_ip}" ] || [ "$(valid_ip_address ${ldap_server_ip})" == "1" ]; then
        if [ -z "${ldap_server_ip}" ]; then
            log_error "Ip address of the ldap server is empty." true
        else
            log_error "Ip address of the ldap server is invalid, ldap_server_ip = ${ldap_server_ip}" true
        fi
        error_tag=1
    fi
    # 检查服务端创建的ldap.crt证书是否存在
    ssh_command "${ldap_server_ip}" "ls /etc/openldap/certs/ldap.crt" "${root_login_password}"
    if [ "0" != "$?" ]; then
      ssh_command "${ldap_server_ip}" "ls ${base_directory}/service_script/ldap.crt | grep ldap.crt" "${root_login_password}"
      if [ "0" != "$?" ]; then
            log_error "No ldap.crt certificate is generated on ldap server, ldap_server_ip = ${ldap_server_ip}" true
            error_tag=1
        fi
    fi
    return ${error_tag}
}

# 校验NTP或者Chrony参数合法性
# 校验通过返回值为0 不通过返回值为1
function valid_ntp_chrony() {
    local error_tag=0
    local ntp_server_ip=$(get_ini_value service_conf ntp_server_ip)
    if [ -z "${ntp_server_ip}" ] || [ "$(valid_ip_address ${ntp_server_ip})" == "1" ]; then
        if [ -z "${ntp_server_ip}" ]; then
            log_error "Ip address of the ntp or chrony server is empty." true
        else
            log_error "Ip address of the ntp or chrony server is invalid, server_ip = ${ntp_server_ip}" true
        fi
        error_tag=1
    fi
    return ${error_tag}
}

# 校验挂载共享目录
function valid_mount_storage() {
    local error_tag=0
    if [ "$(rpm -qa ansible)" == "" ]; then
        log_error "Ansible is not installed or fails to be installed." true
        error_tag=1
    fi
    local storage_ip=$(get_ini_value basic_conf basic_share_storage_ip)
    if [ -z "${storage_ip}" ] || [ "$(valid_ip_address ${storage_ip})" == "1" ]; then
        if [ -z "${storage_ip}" ]; then
            log_error "Ip address of the storage is empty." true
        else
            log_error "Ip address of the storage is invalid, storage_ip = ${storage_ip}" true
        fi
        error_tag=1
    fi
    local storage_share_dir=$(get_ini_value basic_conf basic_share_storage_directory /share_nfs)
    local share_dir=$(get_ini_value basic_conf basic_shared_directory /share)
    if [ "${storage_ip}" == "${om_machine_ip}" ] && [ "${storage_share_dir}" == "${share_dir}" ]; then
        log_error "Storage node and O&M node are on the same host, and the directory names must be different." true
        error_tag=1
    fi
    # 检查所有节点是否具备安装NFS客户端条件
    ansible ${ansible_group_name} -m shell -a "${base_directory}/basic_script/pre_install.sh ${root_dir} 2"
    if [ "$?" != "0" ]; then
        error_tag=1
    fi
    return ${error_tag}
}

# 脚本执行合法性检查
# TODO 20230307_各自实现自己脚本的合法性检查,返回0（成功）或者1（失败）
function required_check() {
    if [ -z "${om_machine_ip}" ]; then
        log_error "Ip address of O&M node is not configured, please check." true
        return 1
    fi
    if [ -z "$(echo "${current_ip_addr}" | grep "${om_machine_ip}")" ]; then
        log_error "Current script needs to be executed on the O&M node, please check." true
        return 1
    fi
    if [ -z "$(get_ini_value common_global_conf common_sys_user_password)" ]; then
        log_error "DonauKit business users password is not configured, please check." true
        return 1
    fi
    if [ -z "$(get_ini_value common_global_conf common_sys_root_password)" ]; then
        log_error "Operating system root password is not configured, please check." true
        return 1
    fi
    if [ -z "$(get_ini_value service_conf ldap_login_password)" ]; then
        log_error "Ldap administrator password is not configured, please check." true
        return 1
    fi
#    if [ -z "$(yum list | grep sshpass)" ] && [ "$(rpm -qa sshpass)" == "" ]; then
#        # 如果yum源中没有找到再从sourcecode软件包中去找
#        local sshpass_rpm=$(find_file_by_path ${sourcecode_dir}/ansible/ sshpass rpm)
#        if [ -z "${sshpass_rpm}" ]; then
#            log_error "Sshpass dependency package does not exist, system exit." true
#            return 1
#        fi
#    fi
}

# 该方法主要用来判断提醒用户是否要进行初始化操作
function init_tips_check() {
    # 刷脚本的权限和属主
    if [ -n "${sourcecode_dir}" ] && [ -n "${base_directory}" ]; then
      chmod 755 ${sourcecode_dir}/*
      chown root:root ${sourcecode_dir}/*
      chmod +x ${base_directory}/*.sh
      chmod +x ${base_directory}/basic_script/*.sh
      chmod +x ${base_directory}/service_script/*.sh
      chmod +x ${base_directory}/benchmark_script/*.sh
    else
      log_error "The tool directory is incorrect. Please check." true
      exit 1
    fi
    yum list 1>/dev/null 2>/dev/null
    if [ $? -eq 1 ] && [ "$(rpm -qa ansible)" == "" ]; then
        return 1
    fi
    yum list | grep vim 1>/dev/null 2>/dev/null
    # 检查YUM源是否已挂载
    if [ $? -eq 1 ] || [ "$(df -h | grep -o /mnt)" == "" ]; then
        # 检查ANSIBLE是否已安装
        if [ "$(rpm -qa ansible)" == "" ]; then
            return 1
        fi
    fi
}

# 基础配置项选择菜单
function basic_menu() {
    select action_basic in "installation and configuration all scripts." "yum installation and configuration scripts." "ansible installation and configuration scripts." "hostname installation and configuration scripts." "pass_free installation and configuration scripts." "selinux installation and configuration scripts." "firewall installation and configuration scripts." "mellanox installation and configuration scripts." "ulimit installation and configuration scripts." "/etc/hosts synchronize." "return to upper-level menu." "system exit."; do
        if [ "${action_basic}" == "installation and configuration all scripts." ]; then
            if [ "$(rpm -qa ansible)" == "" ]; then
                log_error "Ansible is not installed or fails to be installed." true
                return
            fi
            log_tips "Installing Configuration... it may take several minutes, please wait." true
            local mellanox_driver_name=$(find_file_by_path ${sourcecode_dir}/ MLNX_OFED_LINUX tgz)
            test_ansible
            # 同步/root/.ssh/到其它所有节点
            ansible ${ansible_group_name}":!"${om_machine_ip} -m copy -a "src=/root/.ssh/ dest=/root/.ssh/ mode=0600"
            ansible ${ansible_group_name}":!"${om_machine_ip} -m copy -a "src=${sourcecode_dir}/${mellanox_driver_name} dest=${sourcecode_dir}/"
            # 同步http-local.repo文件到其它节点配置yum client
            # 使用YUM网络源必须先要关闭防火墙
            ansible ${ansible_group_name} -m shell -a "${base_directory}/basic_script/cac_firewall.sh false false ${root_dir} true"
            ansible ${ansible_group_name}":!"${om_machine_ip} -m file -a "path=/etc/yum.repos.bak state=directory"
            ansible ${ansible_group_name}":!"${om_machine_ip} -m shell -a "mv -f /etc/yum.repos.d/* /etc/yum.repos.bak/"
            ansible ${ansible_group_name}":!"${om_machine_ip} -m copy -a "src=${base_directory}/http-local.repo dest=/etc/yum.repos.d/"
            ansible ${ansible_group_name}":!"${om_machine_ip} -m shell -a "yum clean all && yum makecache"
            # YUM源挂载后检查并安装基础命令
            ansible ${ansible_group_name}":!"${om_machine_ip} -m shell -a "${base_directory}/basic_script/pre_install.sh ${root_dir} 1"
            # 同步/etc/hosts文件到其它节点（先生成后同步）
            create_etc_hosts
            ansible all":!"${om_machine_ip} -m copy -a "src=/etc/hosts dest=/etc/"
            ansible ${ansible_group_name}":!"${om_machine_ip} -m copy -a "src=/etc/profile dest=/etc/"
            # 执行批量安装配置脚本
            ansible ${ansible_group_name} -m shell -a "${base_directory}/basic_script/auto_install_script.sh ${root_dir}" -t ${ansible_log_path}
            ansible_run_stats
            # 提示重启节点配置生效
            # 重启除运维节点所有节点
            read_input_yes_or_no "do you need to \033[5;31mreboot \033[0;33moperating system immediately?"
            if [ $? == 1 ]; then
              log_tips "Rebooting... it may take several minutes, please wait." true
              if [ -n "$(cat /etc/system-release | grep -i -w openEuler)" ]; then
                  # 欧拉系统自带ANSIBLE不支持reboot模块
                  ansible ${ansible_group_name} -m shell -a "reboot"
              else
                  ansible ${ansible_group_name} -m reboot
              fi
            fi

        elif [ "${action_basic}" == "yum installation and configuration scripts." ]; then
            test_ansible
            # 关闭防火墙，确保单步可执行
            ansible ${ansible_group_name} -m shell -a "${base_directory}/basic_script/cac_firewall.sh false false ${root_dir} true"
            ansible ${ansible_group_name}":!"${om_machine_ip} -m file -a "path=/etc/yum.repos.bak state=directory"
            ansible ${ansible_group_name}":!"${om_machine_ip} -m shell -a "mv -f /etc/yum.repos.d/* /etc/yum.repos.bak/"
            ansible ${ansible_group_name}":!"${om_machine_ip} -m copy -a "src=${base_directory}/http-local.repo dest=/etc/yum.repos.d/"
            ansible ${ansible_group_name}":!"${om_machine_ip} -m shell -a "yum clean all && yum makecache" -t ${ansible_log_path}
            # YUM源挂载后检查并安装基础命令
            ansible ${ansible_group_name}":!"${om_machine_ip} -m shell -a "${base_directory}/basic_script/pre_install.sh ${root_dir} 1"
            ansible_shell_stats
        elif [ "${action_basic}" == "ansible installation and configuration scripts." ]; then
            if [ -n "$(rpm -qa ansible)" ]; then
                log_info "Ansible has been initialized and does not need to be installed." true
            else
                ${base_directory}/basic_script/cas_ansible.sh false false ${root_dir} true
            fi
        elif [ "${action_basic}" == "hostname installation and configuration scripts." ]; then
            test_ansible
            ansible ${ansible_group_name} -m shell -a "${base_directory}/basic_script/cac_hostname.sh false false ${root_dir} true" -t ${ansible_log_path}
            ansible_run_stats
        elif [ "${action_basic}" == "pass_free installation and configuration scripts." ]; then
            test_ansible
            ansible ${ansible_group_name}":!"${om_machine_ip} -m copy -a "src=/root/.ssh/ dest=/root/.ssh/ mode=0600" -t ${ansible_log_path}
            ansible_copy_stats
        elif [ "${action_basic}" == "selinux installation and configuration scripts." ]; then
            test_ansible
            ansible ${ansible_group_name} -m shell -a "${base_directory}/basic_script/cac_selinux.sh false false ${root_dir} true" -t ${ansible_log_path}
            ansible_run_stats
        elif [ "${action_basic}" == "firewall installation and configuration scripts." ]; then
            test_ansible
            ansible ${ansible_group_name} -m shell -a "${base_directory}/basic_script/cac_firewall.sh false false ${root_dir} true" -t ${ansible_log_path}
            ansible_run_stats
        elif [ "${action_basic}" == "mellanox installation and configuration scripts." ]; then
            log_tips "Installing mellanox driver... it may take several minutes, please wait."
            test_ansible
            local mellanox_driver_name=$(find_file_by_path ${sourcecode_dir}/ MLNX_OFED_LINUX tgz)
            ansible ${ansible_group_name}":!"${om_machine_ip} -m copy -a "src=${sourcecode_dir}/${mellanox_driver_name} dest=${sourcecode_dir}/"
            ansible ${ansible_group_name} -m shell -a "${base_directory}/basic_script/cas_mellanox.sh false false ${root_dir} true" -t ${ansible_log_path}
            ansible_run_stats
        elif [ "${action_basic}" == "ulimit installation and configuration scripts." ]; then
            test_ansible
            ansible ${ansible_group_name} -m shell -a "${base_directory}/basic_script/cac_ulimit.sh false false ${root_dir} true" -t ${ansible_log_path}
            ansible_run_stats
        elif [ "${action_basic}" == "/etc/hosts synchronize." ]; then
            test_ansible
            create_etc_hosts
            ansible all":!"${om_machine_ip} -m copy -a "src=/etc/hosts dest=/etc/"
            ansible all -m copy -a "src=/etc/profile dest=/etc/" -t ${ansible_log_path}
            ansible_copy_stats
        elif [ "${action_basic}" == "return to upper-level menu." ]; then
            main_menu
        elif [ "${action_basic}" == "system exit." ]; then
            exit 0
        else
            log_error "selected drop-down list does not match the defined, please select again." true
        fi

        # 执行完毕后自动回显当前菜单
        echo
        basic_menu
    done
}

# 基础服务选择菜单
function service_menu() {
    select action_ntp_ldap in "automatic chrony server and client script." "automatic chrony_server script." "automatic chrony_client script." "automatic ldap server and client script." "automatic ldap_server script." "automatic ldap_client script." "return to upper-level menu." "system exit."; do
        if [ "${action_ntp_ldap}" == "automatic chrony server and client script." ]; then
            if [ "${ansible_group_name}" != "expansion" ];then
                valid_ntp_chrony
                if [ "${?}" == "0" ]; then
                    ${base_directory}/service_script/install_chrony_server.sh ${root_dir}
                    ${base_directory}/service_script/install_chrony_client.sh ${root_dir}
                fi
            else
              log_error "Node expansion does not support this operation." true
            fi
        elif [ "${action_ntp_ldap}" == "automatic chrony_server script." ]; then
            if [ "${ansible_group_name}" != "expansion" ];then
                 valid_ntp_chrony
                if [ "${?}" == "0" ]; then
                    ${base_directory}/service_script/install_chrony_server.sh ${root_dir}
                fi
            else
                log_error "Node expansion does not support this operation." true
            fi
        elif [ "${action_ntp_ldap}" == "automatic chrony_client script." ]; then
            valid_ntp_chrony
            if [ "${?}" == "0" ]; then
                ${base_directory}/service_script/install_chrony_client.sh ${root_dir}
            fi
        elif [ "${action_ntp_ldap}" == "automatic ldap server and client script." ]; then
            if [ "${ansible_group_name}" != "expansion" ];then
                valid_ldap_server
                if [ "${?}" == "0" ]; then
                    ansible ${ansible_group_name} -m shell -a "${base_directory}/basic_script/pre_install.sh ${root_dir} 3"
                    if [ "$?" == "0" ]; then
                      ${base_directory}/service_script/install_ldap_server.sh ${root_dir}
                    fi
                    log_info "Generate and update /etc/hosts file (domain name IP address mapping)." true
                    # 生成刷新/etc/hosts文件（域名IP映射）
                    create_etc_hosts
                    # 同步到其它节点
                    ansible ${ansible_group_name}":!"${om_machine_ip} -m copy -a "src=/etc/hosts dest=/etc/"
                    ansible ${ansible_group_name} -m shell -a "${base_directory}/basic_script/pre_install.sh ${root_dir} 4"
                    ${base_directory}/service_script/install_ldap_client.sh ${root_dir}
                fi
            else
                log_error "Node expansion does not support this operation." true
            fi
        elif [ "${action_ntp_ldap}" == "automatic ldap_server script." ]; then
            if [ "${ansible_group_name}" != "expansion" ];then
                valid_ldap_server
                if [ "${?}" == "0" ]; then
                    ansible ${ansible_group_name} -m shell -a "${base_directory}/basic_script/pre_install.sh ${root_dir} 3"
                    if [ "$?" == "0" ]; then
                      ${base_directory}/service_script/install_ldap_server.sh ${root_dir}
                    fi
                    log_info "Generate and update /etc/hosts file (domain name IP address mapping)." true
                    # 生成刷新/etc/hosts文件（域名IP映射）
                    create_etc_hosts
                    # 同步到其它节点
                    ansible ${ansible_group_name}":!"${om_machine_ip} -m copy -a "src=/etc/hosts dest=/etc/"
                fi
            else
                log_error "Node expansion does not support this operation." true
            fi
        elif [ "${action_ntp_ldap}" == "automatic ldap_client script." ]; then
            valid_ldap_client
            if [ "${?}" == "0" ]; then
                ansible ${ansible_group_name} -m shell -a "${base_directory}/basic_script/pre_install.sh ${root_dir} 4"
                ${base_directory}/service_script/install_ldap_client.sh ${root_dir}
            fi
        elif [ "${action_ntp_ldap}" == "return to upper-level menu." ]; then
            main_menu
        elif [ "${action_ntp_ldap}" == "system exit." ]; then
            exit 0
        else 
            log_error "selected drop-down list does not match the defined, please select again." true
        fi
        # 执行完毕后自动回显当前菜单
        echo
        service_menu
    done
}

# benchmark测试工具选择菜单
function benchmark_menu() {
    select action_benchmark in "auto run cuda toolkit script." "auto run benchmark all scripts." "auto run bisheng_hmpi_kml script." "auto run osu script." "auto run stream script." "auto run hpl script." "return to upper-level menu." "system exit."; do
        if [ "${action_benchmark}" == "auto run cuda toolkit script." ]; then
            if [ "$(rpm -qa ansible)" == "" ]; then
                log_error "Ansible is not installed or fails to be installed." true
            else
                ansible ${ansible_group_name} -m shell -a "${base_directory}/basic_script/cas_cuda.sh false false ${root_dir} true" -t ${ansible_log_path}
                ansible_run_stats
            fi
        elif [ "${action_benchmark}" == "auto run benchmark all scripts." ]; then
            ${base_directory}/benchmark_script/compile_bisheng_hmpi_kml.sh
            ${base_directory}/benchmark_script/compile_osu.sh
            ${base_directory}/benchmark_script/compile_stream.sh
            ${base_directory}/benchmark_script/compile_hpl.sh
        elif [ "${action_benchmark}" == "auto run bisheng_hmpi_kml script." ]; then
            ${base_directory}/benchmark_script/compile_bisheng_hmpi_kml.sh
        elif [ "${action_benchmark}" == "auto run osu script." ]; then
            ${base_directory}/benchmark_script/compile_osu.sh
        elif [ "${action_benchmark}" == "auto run stream script." ]; then
            ${base_directory}/benchmark_script/compile_stream.sh
        elif [ "${action_benchmark}" == "auto run hpl script." ]; then
            ${base_directory}/benchmark_script/compile_hpl.sh
        elif [ "${action_benchmark}" == "return to upper-level menu." ]; then
            main_menu
        elif [ "${action_benchmark}" == "system exit." ]; then
            exit 0
        else 
            log_error "selected drop-down list does not match the defined, please select again." true
        fi
        # 执行完毕后自动回显当前菜单
        echo
        benchmark_menu
    done
}

# 挂载存储菜单
# 注意：目前只实现NFS客户端挂载，DPC经讨论暂时不做实现。
function mount_storage_menu() {
    select action_mount in "auto run nfs client script." "return to upper-level menu." "system exit."; do
        if [ "${action_mount}" == "auto run nfs client script." ]; then
            valid_mount_storage
            if [ "${?}" == "0" ]; then
                ansible ${ansible_group_name} -m shell -a "${base_directory}/basic_script/cas_nfs.sh false false ${root_dir} true" -t ${ansible_log_path}
                ansible_run_stats
            fi
        elif [ "${action_mount}" == "return to upper-level menu." ]; then
            main_menu
        elif [ "${action_mount}" == "system exit." ]; then
            exit 0
        else 
            log_error "selected drop-down list does not match the defined, please select again." true
        fi
        # 执行完毕后自动回显当前菜单
        echo
        mount_storage_menu
    done
}

# 主菜单
function main_menu() {
    # 手动选择需要执行的方法
    select action in "auto run initialization script." "auto run operating system configuration script." "auto run mount storage device scripts." "auto run chrony ldap service installation script." "auto run donaukit users and directory script." "auto run benchmark tools and cuda toolkit installation scripts." "auto run check scripts." "system exit."; do
        if [ "${action}" == "auto run initialization script." ]; then
            ${base_directory}/basic_script/auto_init_script.sh ${root_dir}
            if [ $? -ne 0 ] ; then
                exit  1
            fi
            test_ansible
            # 脚本及依赖软件同步
            ansible ${ansible_group_name}":!"${om_machine_ip} -m copy -a "src=${base_directory}/ dest=${base_directory}/ mode=0755"
            if [ -d "${sourcecode_dir}/jq/" ] && [ -n "$(ls ${sourcecode_dir}/jq/)" ]; then
                ansible ${ansible_group_name}":!"${om_machine_ip} -m copy -a "src=${sourcecode_dir}/jq dest=${sourcecode_dir}/"
            fi
            if [ -d "${sourcecode_dir}/ansible/" ] && [ -n "$(ls ${sourcecode_dir}/ansible/)" ]; then
                ansible ${ansible_group_name}":!"${om_machine_ip} -m copy -a "src=${sourcecode_dir}/ansible dest=${sourcecode_dir}/"
            fi
            local tcsh_rpm=$(find_file_by_path ${sourcecode_dir}/ tcsh rpm)
            if [ -n "${tcsh_rpm}" ]; then
                ansible ${ansible_group_name}":!"${om_machine_ip} -m copy -a "src=${sourcecode_dir}/${tcsh_rpm} dest=${sourcecode_dir}/"
            fi
            # 安装LDAP服务端所需的依赖包
            local migrationtools=$(find_file_by_path ${sourcecode_dir}/ migrationtools rpm)
            if [ -n "${migrationtools}" ]; then
                ansible ${ansible_group_name}":!"${om_machine_ip} -m copy -a "src=${sourcecode_dir}/${migrationtools} dest=${sourcecode_dir}/"
            fi
        elif [ "${action}" == "auto run operating system configuration script." ]; then
            basic_menu
        elif [ "${action}" == "auto run mount storage device scripts." ]; then
            mount_storage_menu
        elif [ "${action}" == "auto run chrony ldap service installation script." ]; then
            service_menu
        elif [ "${action}" == "auto run donaukit users and directory script." ]; then
            local error_tag=0
            # 获取共享目录
            local share_dir=$(get_ini_value basic_conf basic_shared_directory /share)
            if [ -z "$(df -h | grep -o ${share_dir})" ]; then
                log_error "Current operation cannot be performed because the shared directory [${share_dir}] is not mounted." true
                error_tag=1
            fi
            if [ "${error_tag}" == "0" ]; then
                # 所有节点创建DonauKit业务用户
                ansible ${ansible_group_name} -m shell -a "${base_directory}/basic_script/cac_users.sh false false ${root_dir} true" -t ${ansible_log_path}
                ansible_run_stats  
                # 运维节点创建规划目录
                if [ "${ansible_group_name}" == "all" ] && [ "${share_dir}" != "/${root_dir}" ]; then
                    ${base_directory}/basic_script/cac_directory.sh false false ${root_dir} true
                    #清理配置文件涉及到的密码
                    modify_ini_value common_global_conf common_sys_user_password ""
                    modify_ini_value common_global_conf common_sys_root_password ""
                    modify_ini_value service_conf ldap_login_password ""
                    log_tips "Copying scripts to shared directory is in progress... do not interrupt." true
                    cp -r ${base_directory}/ ${share_dir}/software/tools/
                    cp -r ${sourcecode_dir}/ ${share_dir}/software/
                    # ansible all -m file -a "path=/${root_dir}/hpcpilot/ state=absent"
                    log_tips "Scripts move completed, follow-up operations are performed in the shared directory." false
                    # 在共享目录执行的提示，闪烁显示，以比较明确的提示用户
                    echo -e "\033[1;33;42m Scripts move completed, follow-up operations are performed in the shared directory.\033[0m\n \033[33muse 'cd $share_dir/software/tools/hpcscript'\033[0m"
                fi
            fi
        elif [ "${action}" == "auto run benchmark tools and cuda toolkit installation scripts." ]; then
            local share_dir=$(get_ini_value basic_conf basic_shared_directory /share)
            if [ "${share_dir}" == "/${root_dir}" ] && [ -n "$(df -h | grep -o -w ${share_dir})" ]; then
                benchmark_menu
            else
                log_error "Storage is not mounted or executed in a non-shared directory." true
            fi
        elif [ "${action}" == "auto run check scripts." ]; then
            if [ "$(rpm -qa ansible)" == "" ]; then
                log_error "Ansible is not installed or fails to be installed." true
            else
                log_tips "Checking in progress... do not interrupt." true
                test_ansible
                ansible all -m shell -a "${base_directory}/basic_script/auto_check_script.sh ${root_dir}" -t ${ansible_log_path}
                ansible_run_stats
            fi
        elif [ "${action}" == "system exit." ]; then
            exit_and_cleanENV 0
        else
            log_error "selected drop-down list does not match the defined, please select again." true
        fi
        # 执行完毕后自动回显当前菜单
        echo
        main_menu
    done
}

############### 主函数入口 ###############
function main() {
    required_check
    if [ "$?" == "1" ]; then
        exit 1
    fi
    init_tips_check
    if [ "$?" == "1" ]; then
        while true 
        do
            read -r -p "$(echo -e "\033[33mO&M node is not mounted yum and ansible is not installed, please perform initialization first ? [y/n]\033[0m")" input
            if [ -n "$(echo "YES Y" | grep -w -i ${input})" ]; then
                ${base_directory}/basic_script/auto_init_script.sh ${root_dir}
                break
            elif [ -n "$(echo "NO N" | grep -w -i ${input})" ]; then
                exit 0
            else
                log_error "Invalid input parameter [${input}], please enter again [y/n]." true
            fi    
        done
    fi
    log_tips "Welcome to hpcpilot, please input ssh PassW for ansible." true
    test_ansible
    ansible ${ansible_group_name}":!"${om_machine_ip} -m copy -a "src=${base_directory}/ dest=${base_directory}/ mode=0755"
    log_tips "Welcome to hpcpilot, please select the script to execute." true
    main_menu
}

main
