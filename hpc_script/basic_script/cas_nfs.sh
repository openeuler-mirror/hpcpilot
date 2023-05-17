#
# Copyright (c) Huawei Technologies Co., Ltd. 2022-2022. All rights reserved.
#
#!/usr/bin/env bash
######################################################################
# 脚本描述：提供NFS服务端安装配置以及客户端NFS安装配置挂载自动化脚本              #
# 注意事项：安排配置NFS服务端需要修改代码                                    #
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

# 获取配置文件setting中的共享目录
share_hpc_dir=$(get_ini_value basic_conf basic_shared_directory /share)
# 获取配置文件NFS共享存储目录
share_nfs_dir=$(get_ini_value basic_conf basic_share_storage_directory /share_nfs)
# 当前主机IP地址
current_ip_addr=$(get_current_host_ip)
# 获取配置文件NFS共享存储IP地址
share_nfs_ip=$(get_ini_value basic_conf basic_share_storage_ip)
# nfs服务配置文件内容
nfs_conf_content="${share_nfs_dir} *(rw,no_subtree_check,fsid=11,no_root_squash)\n"
# 共享目录配置文件内容
nfs_share_content="\n${share_nfs_ip}:${share_nfs_dir}      ${share_nfs_dir}       nfs       nolock       0     2"

# 检查NFS安装部署是否正确
function check_nfs() {
    local ret_utils_code=0
    local ret_utils_start_code=0
    local ret_rpcbind_code=0
    local ret_rpcbind_start_code=0
    local ret_nfs_share_code=0
    # 检查nfs-utils服务是否已经安装
    local is_setup_utils=$(rpm -qa nfs-utils | grep -o "nfs-utils")
    if [ "${is_setup_utils}" == "" ]; then
        ret_utils_code=1
    fi
    # 检查rpcbind服务是否已安装
    local is_setup_rpcbind=$(rpm -qa rpcbind | grep -o "rpcbind")
    if [ "${is_setup_rpcbind}" == "" ]; then
        ret_rpcbind_code=1
    else
        if [ "$(systemctl status rpcbind.service | grep -o "active (running)")" == "" ]; then
            ret_rpcbind_start_code=1
        fi
    fi
    # 检查共享目录配置文件内容是否正确
    if [ -n "$(tail /etc/fstab | grep -o "${share_nfs_ip}:${share_nfs_dir}")" ]; then
        local ret_nfs_share_code=0
    else
        local ret_nfs_share_code=1
    fi

    ret_info=(${ret_utils_code} ${ret_utils_start_code} ${ret_rpcbind_code} ${ret_rpcbind_start_code} ${ret_nfs_share_code})
    echo ${ret_info[@]}
}

# NFS检查结果打印输出
function check_nfs_result() {
    echo -e ""
    echo -e "\033[33m==================[11]计算节点挂载配置存储NFS检查结果=====================\033[0m"
    local return_msg=($(check_nfs))
    if [ "${return_msg[0]}" == "0" ]; then
        echo -e "\033[33m==\033[0m\033[32m  nfs-utils服务已安装                                  [ √ ]\033[0m          \033[33m==\033[0m"
        if [ "${return_msg[1]}" == "0" ]; then
            echo -e "\033[33m==\033[0m\033[32m  nfs.service服务已启动                                [ √ ]\033[0m          \033[33m==\033[0m"
        else
            echo -e "\033[33m==\033[0m\033[31m  nfs.service服务未启动                                [ X ]\033[0m          \033[33m==\033[0m"
        fi
    else
        echo -e "\033[33m==\033[0m\033[31m  nfs-utils服务未安装                                  [ X ]\033[0m          \033[33m==\033[0m"
    fi
    if [ "${return_msg[2]}" == "0" ]; then
        echo -e "\033[33m==\033[0m\033[32m  rpcbind服务已安装                                    [ √ ]\033[0m          \033[33m==\033[0m"
        if [ "${return_msg[3]}" == "0" ]; then
            echo -e "\033[33m==\033[0m\033[32m  rpcbind服务已启动                                    [ √ ]\033[0m          \033[33m==\033[0m"
        else
            echo -e "\033[33m==\033[0m\033[31m  rpcbind服务未启动                                    [ X ]\033[0m          \033[33m==\033[0m"
        fi
    else
        echo -e "\033[33m==\033[0m\033[31m  rpcbind服务未安装                                    [ X ]\033[0m          \033[33m==\033[0m"
    fi
    
    if [ "${return_msg[4]}" == "0" ]; then
        echo -e "\033[33m==\033[0m\033[32m  共享目录配置文件[/etc/fstab]配置正常                 [ √ ]\033[0m          \033[33m==\033[0m"
    else
        echo -e "\033[33m==\033[0m\033[31m  共享目录配置文件[/etc/fstab]配置异常                 [ √ ]\033[0m          \033[33m==\033[0m"
    fi
    echo -e "\033[33m==================[11]计算节点挂载配置存储NFS检查结果=====================\033[0m"
}


# 安装NFS服务需要的依赖
function setup_nfs_dependent() {
    # 检查nfs_utils服务是否已安装
    if [ "$(rpm -qa nfs-utils)" == "" ]; then
        yum install -y nfs-utils >> ${operation_log_path}/access_all.log 2>&1
    fi 
    # 检查rpcbind服务是否已安装
    if [ "$(rpm -qa rpcbind)" == "" ]; then
        yum install -y rpcbind >> ${operation_log_path}/access_all.log 2>&1
    fi
}

# 配置开机自启动
function config_auto_fstab() {
    # 1.判断是否存在之前已配置的NFS开机自启动，如果存在则删除
    local line_nums=($(echo -n $(cat /etc/fstab | grep -n "nfs nolock 0 2" | cut -d ":" -f 1)))
    if [ -n "${line_nums}" ]; then
        for (( i = 0; i < ${#line_nums[@]}; i++ )); do
            # 删除之前配置的自启动配置内容
            sed -i "${line_nums[i]}d" /etc/fstab
        done
        # 删除多余空白行
        sed -i /^[[:space:]]*$/d /etc/fstab
    fi
    # 2.组装NFS开机自启动配置内容
    local new_fstab_config="\n${share_nfs_ip}:${share_nfs_dir} ${share_nfs_dir} nfs nolock 0 2"
    # 3.获取NFS开机自启动原内容
    local old_fstab_config=$(tail /etc/fstab)
    # 4.为保险安全期间再次做判断
    if [[ "${old_fstab_config}" =~ "${new_fstab_config}" ]]; then
        log_warn "[${share_nfs_dir}] directory has been configured already and does not need to be modified." false
    else
        # 5.追加NFS开机自动启配置内容到/etc/fstab文件
        echo -ne ${new_fstab_config} >>/etc/fstab
    fi
}

# 安装配置NFS服务端
function install_nfs_server() {
    setup_nfs_dependent
    # 检查并创建共享目录
    if [ ! -d "${share_nfs_dir}/" ]; then
        mkdir -m 755 -p ${share_nfs_dir}/
    fi
    if [ "${share_nfs_ip}" == "${current_ip_addr}" ]; then
        local new_share_config="${share_nfs_dir} *(rw,no_subtree_check,fsid=11,no_root_squash)\n"
        local old_share_config=$(tail /etc/exports)
        if [[ "${old_share_config}" =~ "${new_share_config}" ]]; then
            log_warn "[${share_nfs_dir}] directory has been configured already and does not need to be modified." false
        else
            echo -ne ${new_share_config} >>/etc/exports
        fi
        # 使配置文件修改生效
        exportfs -r
        # 启动NFS服务
        systemctl enable rpcbind.service
        systemctl enable nfs-server.service
        if [ "$(systemctl status rpcbind.service | grep -o "active (running)")" != "" ]; then
            systemctl restart rpcbind.service
        else
            systemctl start rpcbind.service
        fi
        if [ "$(systemctl status nfs-server.service | grep -o "active (exited)")" != "" ]; then
            systemctl restart nfs-server.service
        else
            systemctl start nfs-server.service
        fi
        # 配置开机自启动
        config_auto_fstab
    fi
}

# 安装配置NFS客户端
function install_nfs_client() {
    # 安装nfs-utils和rpcbind
    setup_nfs_dependent
    # 检查并创建共享目录
    if [ ! -d "${share_hpc_dir}/" ]; then
        mkdir -m 755 -p ${share_hpc_dir}/
    fi
    # NFS Client 配置设置
    # 启动NFS相关服务
    systemctl enable rpcbind.service
    if [ "$(systemctl status rpcbind.service | grep -o "active (running)")" != "" ]; then
        systemctl restart rpcbind.service
    else
        systemctl start rpcbind.service
    fi
    # 挂载共享目录
    mount -t nfs ${share_nfs_ip}:${share_nfs_dir} ${share_hpc_dir}
    # 配置开机自启动
    config_auto_fstab
}

# NFS安装配置结果打印输出
function install_nfs_result() {
    install_nfs_client
    check_nfs_result
}

# 脚本执行合法性检查
function required_check() {
    # 运维节点OM配置检查
    if [ -z "${share_nfs_ip}" ]; then
        log_error "Ip address of share storage is not configured, please check." true
        return 1
    fi
    if [ "$(valid_ip_address ${share_nfs_ip})" == "1" ]; then
        log_error "Ip address [${share_nfs_ip}] of share storage is invalid, please check." true
        return 1
    fi
    if [ "$(rpm -qa nfs-utils)" == "" ]; then
        yum install -y nfs-utils >> ${operation_log_path}/access_all.log 2>&1
    fi 
    if [ "$(rpm -qa rpcbind)" == "" ]; then
        yum install -y rpcbind >> ${operation_log_path}/access_all.log 2>&1
    fi
    showmount -e ${share_nfs_ip}
    if [ "$?" == "1" ]; then
        log_error "NFS server [${share_nfs_ip}] is not configured, please check." true
        return 1
    fi
    if [ -z "$(showmount -e ${share_nfs_ip} | grep -w "${share_nfs_dir}")" ]; then
        log_error "Shared directory on nfs server is inconsistent with the configuration, please check." true
        return 1
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
manual_script_action ${is_manual_script} ${is_open_debug} required_check check_nfs_result install_nfs_result ${4}
