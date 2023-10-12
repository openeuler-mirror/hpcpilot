#
# Copyright (c) Huawei Technologies Co., Ltd. 2022-2022. All rights reserved.
#
#!/usr/bin/env bash
# 提供解决安装过程中ANSIBLE无法调用方法的问题

# 引用公共函数文件开始
if [ "${1}" == "opt" ]; then
    # 定义脚本文件、配置文件存放目录
    base_directory=/${1}/hpcpilot/hpc_script
else
    # 定义脚本文件、配置文件存放目录
    base_directory=/${1}/software/tools/hpc_script
fi
source ${base_directory}/common.sh ${1}
# 引用公共函数文件结束

# NFS客户端安装前检查
function check_nfs_install() {
    local share_nfs_ip=$(get_ini_value basic_conf basic_share_storage_ip)
    # 获取配置文件setting中的共享目录
    local share_hpc_dir=$(get_ini_value basic_conf basic_shared_directory /share)
    # 获取配置文件NFS共享存储目录
    local share_nfs_dir=$(get_ini_value basic_conf basic_share_storage_directory /share_nfs)
    if [ "$(rpm -qa nfs-utils)" == "" ]; then
        yum install -y nfs-utils >> ${operation_log_path}/access_all.log 2>&1
    fi
    if [ "$(rpm -qa rpcbind)" == "" ]; then
        yum install -y rpcbind >> ${operation_log_path}/access_all.log 2>&1
    fi
    # 检查是否配置了NFS服务端
    showmount -e ${share_nfs_ip}
    if [ "$?" == "1" ]; then
        log_error "NFS server [${share_nfs_ip}] is not configured, please check." true
        return 1
    fi
    # 检查NFS服务端配置是否与setting文件设置属性值一致
    if [ -z "$(showmount -e ${share_nfs_ip} | grep "${share_nfs_dir}")" ]; then
        log_error "Shared directory on nfs server is inconsistent with the configuration, please check." true
        return 1
    fi

    # local config_share=($(echo -n $(cat /etc/fstab | grep -w "${share_nfs_ip}:${share_nfs_dir}" | cut -d " " -f 2)))
    local config_share=($(echo -n $(df -h | grep -w "${share_nfs_ip}:${share_nfs_dir}" | awk '{print $6}')))
    if [ -n "${config_share}" ] && [ "${config_share}" != "${share_hpc_dir}"  ]; then
        local current_ip_addr=$(ip addr | awk '/^[0-9]+: / {}; /inet.*global/ {print gensub(/(.*)\/(.*)/, "\\1", "g", $2)}')
        log_error "Current client [${current_ip_addr}] is mounted to [${config_share}] directory, inconsistent with setting.ini [${share_hpc_dir}], please check." true
        return 1
    fi
    return 0
}

function remove_ldap_server() {
    if [ "$(rpm -qa | grep ldap)" != "" ] && [ "$(systemctl status slapd | grep Active)" != "" ]; then
        systemctl stop ldap.service
        yum remove -y openldap
        yum remove -y compat-openldap
        yum remove -y openldap-servers
        yum remove -y openldap-servers-sql
        yum remove -y openldap-devel
        yum remove -y migrationtools
        rm -rf /etc/openldap /var/lib/ldap
        rm -rf /root/ldap-sync/
        userdel ldapDemo
    fi
    return 0
}

function remove_ldap_client() {
    if [ "$(rpm -qa | grep ldap)" != "" ] && [ -f "/usr/bin/ldapsearch" ]; then
        systemctl stop ldap.clients
        yum -y remove openldap-clients
        yum remove -y nss-pam-ldapd
        yum remove -y authconfig
        yum remove -y oddjob
        yum remove -y oddjob-mkhomedir
        rm -rf /var/cache/ldap
        userdel ldapDemo
    fi
    return 0
}

# ${1}=1 表示安装基础命令
# ${1}=2 表示安装NFS安装前检查
# ${1}=3 表示卸载ldap服务端
# ${1}=4 表示卸载ldap客户端
function main() {
    # 检查并安装基础命令
    if [ "${1}" == "1" ]; then
        log_info "Checking and installing basic commands." false
        basic_commands_install
    elif [ "${1}" == "2" ]; then
        check_nfs_install
    elif [ "${1}" == "3" ]; then
        remove_ldap_server
    elif [ "${1}" == "4" ]; then
        remove_ldap_client
    else
        log_warn "Not supported currently commands."
    fi
}

main ${2}