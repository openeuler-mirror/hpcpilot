#
# Copyright (c) Huawei Technologies Co., Ltd. 2022-2022. All rights reserved.
#
#!/usr/bin/env bash
# 基础项安装配置系统初始化脚本，主要用来初始化一键安装脚本准备工作
# 当前脚本不依赖配置文件以及其他外部shell脚本
# set -x

# 挂载运维节点YUM源
# 注意：当前方法不依赖配置文件以及其他外部shell脚本

# 当前主机IP
server_ip=""
# 定义脚本文件、配置文件存放目录
base_directory=/init/
# 定义共享目录配置
share_directories=/share

# 当前操作系统的ISO文件
current_os_yum_iso=""
# 当前操作系统生成的的repo文件名称
current_os_repo_name=""
# 其它类型操作系统ISO文件
others_os_yum_iso=""

# 检查某个目录下文件是否存在某个文件
# 判断依据是如果文件名包含关键字且后缀名为指定的后缀名即为当前需要查找的文件
# 或者文件名以关键字_操作系统英文名称开头的文件即为当前需要需要查找的文件
# 操作系统前缀名称，比如：CentOS、openEuler、Kylin

# 调用方式：函数名 文件所在路径 文件关键字key 文件后缀名
# 返回值：""不存在，否则返回文件名
# 调用举例：`find_file_by_path` /workspace/software/libs cuda run
function find_file_by_path() {
    query_file_name=""
    # 当前操作系统名称
    local current_os_info=($(cat /etc/system-release))
    cd ${1}
    local files=$(ls ${1})
    if [ -n "${files}" ]; then
        for file_name in ${files}; do
            # 判断字符串是否以XXX字符串开头
            if [[ "${file_name}" =~ ^"${2}_${current_os_info[0]}"* ]]; then
                query_file_name=${file_name}
                break
            fi
            if [[ "${file_name}" =~ "${2}" ]] && [ "${file_name##*.}" == "${3}" ]; then
                query_file_name=${file_name}
                break
            fi
        done
    else
        echo -e "\033[31m [${1}] directory is empty.\033[0m"
    fi
    echo ${query_file_name}
}

# 当yum源安装配置完成后检查并安装基础命令
function basic_commands_install() {
    # 列举定义基础命令
    local basic_commands=(net-tools sshpass tree jq tar curl grep sed awk)
    for (( i = 0; i < ${#basic_commands[@]}; i++ )); do
        if [ "$(rpm -qa ${basic_commands[i]})" == "" ]; then
            if [ "$(yum list | grep ${basic_commands[i]})" == "" ]; then
                # 从本地找对应依赖软件安装
                local dependent_file_name=$(find_file_by_path ${base_directory} ${basic_commands[i]} rpm)
                if [ -z "${dependent_file_name}" ]; then
                    echo -e "\033[31m [${basic_commands[i]}] command cannot be found in native.\033[0m"
                else
                    cd ${base_directory}
                    yum install -y ${dependent_file_name} &>/dev/null
                    echo -e "\033[32m [${basic_commands[i]}] command installation succeeded from native.\033[0m"
                fi
            else
                yum install -y ${basic_commands[i]} &>/dev/null
                echo -e "\033[32m [${basic_commands[i]}] command installation succeeded form yum source.\033[0m"
            fi
        else
            echo -e "\033[32m [${basic_commands[i]}] command does not need to be installed.\033[0m"
        fi
    done
}

# 配置网络YUM源和开机自动启
function config_network_yum() {
    # 镜像源挂载完成后获取当前主机IP初始化参数server_ip
    if [ -z "$(rpm -qa net-tools)" ]; then
        yum install -y net-tools
    fi
    server_ip=$(ifconfig -a | grep inet | grep -v 127.0.0.1 | grep -v inet6 | awk '{print $2}' | tr -d "addrs")
    # 2.检查安装httpd服务
    if [ "${3}" == "true" ]; then
        if [ "$(rpm -qa httpd)" == "" ]; then
            yum install -y httpd
            systemctl start httpd.service
        fi
        if [ "$(systemctl status httpd.service | grep -o "active (running)")" == "" ]; then
            systemctl start httpd.service
        fi
    fi
    # 3.将镜像文件拷贝到http目录
    if [ -d "/var/www/html/${4}/" ]; then
        rm -rf /var/www/html/${4}/
    fi
    mkdir -p /var/www/html/${4}
    cp -rf /${1}/* /var/www/html/${4}
    # 4.验证网络YUM源是否配置成功
    # 网络YUM源访问地址
    local yum_http_url=http://${server_ip}/${4}
    local ret_code=$(curl -I -s --connect-timeout 1 ${yum_http_url}/ -w %{http_code} | tail -n1)
    if [ "x${ret_code}" == "x200" ]; then
        echo -e "\033[32m the network yum source is configured successfully.\033[0m"
        local current_date=$(date '+%Y%m%d%H%M%S')
        echo -e "\033[32m the yum image source is mounted successfully, the yum configuration starts...\033[0m"
        echo -e "\033[32m configuring cd-rom mounting for automatic startup upon system startup.\033[0m"
        echo -e "\033[32m backing up [/etc/fstab] file to [/etc/fstab.${current_date}.bak].\033[0m"
        # 5.备份开机自启动文件
        cp /etc/fstab /etc/fstab.${current_date}.bak
        # 6.设置配置开机自动挂载
        # 6.1判断是否存在之前已挂载的YUM自启动配置内容
        local line_nums=($(echo -n $(cat /etc/fstab | grep -n "iso /${1} iso9660 loop 0 0" | cut -d ":" -f 1)))
        if [ -n "${line_nums}" ]; then
            for (( i = 0; i < ${#line_nums[@]}; i++ )); do
                # 删除之前配置的自启动配置内容
                sed -i "${line_nums[i]}d" /etc/fstab
            done
            # 删除多余空白行
            sed -i /^[[:space:]]*$/d /etc/fstab
        fi
        if [[ "$(tail /etc/fstab)" =~ "${base_directory}${2} /${1} iso9660 loop 0 0" ]]; then
            echo -e "\033[32m automatic mounting upon startup has been configured.\033[0m"
        else
            # 6.3追加内容到配置文件中
            echo -ne "\n${base_directory}${2} /${1} iso9660 loop 0 0" >>/etc/fstab
        fi
        # 7.重新生成repo文件
        current_os_repo_name=${base_directory}${4}-http.repo
        if [ -f "${current_os_repo_name}" ]; then
            rm -rf ${current_os_repo_name}
        fi
        echo -ne "[${4}-http]\nname=${4}-http\nbaseurl=${yum_http_url}\nenabled=1\ngpgcheck=0\n\n" >${base_directory}${4}-http.repo
    else
        echo -e "\033[31m network yum source is not configured successfully, system exit.\033[0m"
        exit 1
    fi
}

# 挂载YUM镜像源（支持多镜像源）
# 参数列表：
# ${1}=挂载路径
# ${2}ISO文件名
# ${3}=是否OM节点（true=OM镜像，false=其它镜像）
function mount_yum() {
    # 如果已挂载则先卸载（没有使用自动化挂载）
    # 目的是防止与自动化初始化脚本挂载方式不一致导致不可预知的问题
    if [ "$(df -h | grep -o /${1})" != "" ]; then
        umount /${1}/
    fi
    # 创建YUM源挂载路径
    if [ ! -d "/${1}/" ]; then
        mkdir -m 755 -p /${1}/
    fi
    # 镜像文件前缀名称，比如：CentOS、openEuler、Kylin
    local file_pre_name=$(echo ${2%%-*})
    ############### 挂载YUM源镜像 ###############
    # 1.挂载YUM源
    mount -t iso9660 -o loop ${base_directory}${2} /${1}
    if [ -z "$(df -h | grep -o /${1})" ]; then
        echo -e "\033[31m mounting failed, check the mounting process.\033[0m"
    else
        # 3.配置本地YUM源
        if [ "${3}" == "true" ]; then
            ############### 配置运维节点YUM源 ###############
            # 重新加载fstab文件中的内容
            mount /${1}
            if [ ! -d "/etc/yum.repos.d/repo.bak/" ]; then
                mkdir -m 755 -p /etc/yum.repos.d/repo.bak/
            fi
            mv -f /etc/yum.repos.d/* /etc/yum.repos.d/repo.bak &>/dev/null
            echo -ne "[local]\nname=local\nbaseurl=file:///mnt/\nenabled=1\ngpgcheck=0\n\n" >/etc/yum.repos.d/local.repo
        fi
        # 4.清理和重新加载缓存
        yum clean all && yum makecache
        # 5.配置网络YUM源和开机自动启
        config_network_yum ${1} ${2} ${3} ${file_pre_name}
    fi
}

function init_mount_yum() {
    # 挂载本地YUM源
    mount_yum mnt ${current_os_yum_iso} true
    # 检查安装基础命令
    basic_commands_install
    #    挂载其它YUM源
    #    if [ "${others_os_yum_iso}" != "" ]; then
    #        for (( i = 0; i < ${#others_os_yum_iso[@]}; i++ )); do
    #            # 获取文件前缀名称用于创建挂载的文件夹
    #            local file_pre_name=$(echo ${others_os_yum_iso[i]%%-*})
    #            # 挂载YUM源
    #            mount_yum mnt_${file_pre_name} ${others_os_yum_iso[i]} false
    #        done
    #    fi
}

# 配置NFS网络文件系统服务端
function init_config_nfs() {
    local fsid=11
    for share_dir in ${share_directories}; do
        # 检查并创建共享目录
        if [ ! -d "${share_dir}/" ]; then
            mkdir -m 755 -p ${share_dir}/
        fi
        local new_share_config="${share_dir} *(rw,no_subtree_check,fsid=${fsid},no_root_squash)\n"
        local old_share_config=$(tail /etc/exports)
        if [ "$(grep -w "^${share_dir}" /etc/exports)" != "" ]; then
            echo -e "\033[33m [${share_dir}] directory has been configured already and does not need to be modified.\033[0m"
        else
            echo -ne ${new_share_config} >>/etc/exports
        fi
        fsid=$((${fsid}+1))
    done
    # 使配置文件修改生效
    exportfs -r
    # 启动NFS服务
    systemctl enable rpcbind.service
    systemctl enable nfs-server.service
    systemctl start rpcbind.service
    systemctl start nfs-server.service
    
    # ############### 配置开机自加载启动 ###############
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
    for share_dir in ${share_directories}; do
        # 2.组装NFS开机自启动配置内容
        local new_fstab_config="\n${server_ip}:${share_dir} ${share_dir} nfs nolock 0 2"
        # 3.获取NFS开机自启动原内容
        local old_fstab_config=$(tail /etc/fstab)
        # 4.为保险安全期间再次做判断
        if [[ "${old_fstab_config}" =~ "${new_fstab_config}" ]]; then
            echo -e "\033[33m [${share_dir}] directory has been configured already and does not need to be modified.\033[0m"
        else
            # 5.追加NFS开机自动启配置内容到/etc/fstab文件
            echo -ne ${new_fstab_config} >>/etc/fstab
        fi
    done
}

# 安装NFS服务需要的依赖
function setup_nfs_dependent() {
    # 检查nfs_utils服务是否已安装
    if [ "$(rpm -qa nfs-utils)" != "" ]; then
        # 卸载服务
        yum remove -y nfs-utils
    fi
    if [ "$(rpm -qa rpcbind)" != "" ]; then
        # 卸载服务
        yum remove -y rpcbind
    fi
    
    # 安装服务nfs_utils和rpcbind服务
    yum install -y nfs-utils
    yum install -y rpcbind
}

# 安装NFS网络文件系统服务端
function init_setup_nfs_server() {
    setup_nfs_dependent
    # 配置NFS网络文件系统服务端
    init_config_nfs
    echo -e "\033[32m nfs server installation and configuration succeeded.\033[0m"
}

# 关闭防火墙
function init_close_firewall() {
    if [ "$(firewall-cmd --state)" == "running" ]; then
        # 关闭防火墙
        systemctl stop firewalld
        # 关闭开机自启动[需要重新启动]
        systemctl disable firewalld
        # 更新防火墙规则，立即生效
        firewall-cmd --reload
    else
        echo -e "\033[32m firewall has been closed and does not need to be configured.\033[0m"
    fi
    echo -e "\033[32m close firewall configuration completed done.\033[0m"
}

# 同步文件到所有客户端
function init_sync_file_to_client() {
    if [ "$(rpm -qa sshpass)" == "" ]; then
        yum install -y sshpass
    fi
    # unconnected_client_ip记录连接不上的客户端IP地址
    local unconnected_client_ip=""
    # tail -n +2 从第二行开始读取数据，第一行为标题行
    for line in $(cat ${base_directory}hostname.csv | tail -n +2); do
        # 检查判断字符串长度是否为0
        if [ -n "${line}" ]; then
            local ip_addr=$(echo ${line} | awk -F "," '{print $1}')
            if [[ -n "${ip_addr}" && "${ip_addr}" != "${server_ip}" ]]; then
                # 检查主机的连通性
                ping -c 1 ${ip_addr} 1>/dev/null 2>/dev/null
                if [ $? -eq 0 ]; then
                    echo -e "\033[32m===============current client[${ip_addr}] configuration start===============\033[0m"
                    # 第一次连接需要打通IP，否则需要输入密码验证
                    sshpass -f ${base_directory}.sshpass ssh -o StrictHostKeyChecking=no root@${ip_addr} "echo ''"
                    # 同步NFS_client需要的文件到其它远程服务器
                    echo -e "\033[32m===============synchronizing files, which may take several minutes...===============\033[0m"
                    sshpass -f ${base_directory}.sshpass scp /etc/fstab root@${ip_addr}:/etc/fstab
                    # 创建文件夹备份yum.repos.d文件
                    sshpass -f ${base_directory}.sshpass ssh root@${ip_addr} "mkdir -m 755 -p /etc/yum.repos.d/yum.repos.bak/"
                    sshpass -f ${base_directory}.sshpass ssh root@${ip_addr} "mv /etc/yum.repos.d/*.repo /etc/yum.repos.d/yum.repos.bak/"

                    sshpass -f ${base_directory}.sshpass scp ${current_os_repo_name} root@${ip_addr}:/etc/yum.repos.d/
                    # 执行命令加载远程YUM网络源
                    sshpass -f ${base_directory}.sshpass ssh root@${ip_addr} 'yum clean all && yum makecache'
                    # 创建远程脚本存放目录
                    sshpass -f ${base_directory}.sshpass ssh root@${ip_addr} "mkdir -m 755 -p ${base_directory}"
                    # 同步执行文件脚本到对应/init/目录
                    sshpass -f ${base_directory}.sshpass scp ${base_directory}auto_init_script.sh root@${ip_addr}:${base_directory}
                    # 远程执行客户端init_script_client.sh脚本安装NFS客户端
                    # 赋予远程执行脚本权限
                    sshpass -f ${base_directory}.sshpass ssh root@${ip_addr} "chmod 775 ${base_directory}auto_init_script.sh"
                    # 执行远程脚本
                    sshpass -f ${base_directory}.sshpass ssh root@${ip_addr} "sh ${base_directory}auto_init_script.sh false ${server_ip}"
                    echo -e "\033[32m===============current client[${ip_addr}] configuration finish===============\033[0m"
                else
                    unconnected_client_ip="${unconnected_client_ip}\n${ip_addr}"
                fi
            fi
        fi
    done
    echo -e "\033[49;31m not connected hosts are as follows：${unconnected_client_ip}\033[0m"
}

# 创建业务规划目录
# 注意：当前方法不依赖配置文件以及其他外部shell脚本
function init_create_dir() {
    # 业务目录根目录
    local root_dir=${share_directories}/
    # 业务目录二级目录
    local second_dir=/software
    # 业务目录三级目录(数组形式)
    local third_dir=(/apps /compilers /libs /modules /mpi /tools /sourcecode)
    # 业务目录四级或者五级目录(数组形式)
    local forth_dir=(/tools/hpc_script/basic_script /tools/hpc_script/benchmark_script /tools/hpc_script/service_script /sourcecode/ansible /sourcecode/jq)
    
    # 创建三级目录
    for third in "${third_dir[@]}"; do
        if [ ! -d "${root_dir}${second_dir}${third}" ]; then
            mkdir -m 755 -p ${root_dir}${second_dir}${third}
        fi
    done
    # 创建四级目录
    for forth in "${forth_dir[@]}"; do
        if [ ! -d "${root_dir}${second_dir}${forth}" ]; then
            mkdir -m 755 -p ${root_dir}${second_dir}${forth}
        fi
    done
    echo -e "\033[32m business planning directories has been created.\033[0m"
}

# 清理初始化完成后的安装包、执行脚本以及配置文件
# TODO 20230221_程序执行完进行清理工作，包括删除无用的文件等。
function clear_environment() {
    echo "----------------------------------------"
}

# 对初始化脚本所需文件进行验证
function init_verify() {
    local error_flag=0
    # 当前操作系统名称
    local current_os_info=($(cat /etc/system-release))
    ############### 遍历/init文件夹下所有ISO文件并查找当前系统对应的ISO ###############
    # 在文件夹/init中找到所有系统对应的ISO YUM源
    # 不支持文件夹中/init有多个相同类型（X86 ARM64）操作系统ISO
    if [ ! -d "${base_directory}" ]; then
         echo -e "\033[49;31m current running scripts [${0}] does not [${base_directory}].\033[0m"
         return 1
    fi
    
    local files=$(ls ${base_directory})
    if [ -n "${files}" ]; then
        for file_name in ${files}; do
            if [ "${file_name##*.}" == "iso" ]; then
                if [[ "${file_name}" =~ "${current_os_info[0]}" ]]; then
                    current_os_yum_iso=${file_name}
                else
                    if [ -z "${others_os_yum_iso}" ]; then
                        others_os_yum_iso[0]=${file_name}
                    else
                        local array_length=${#others_os_yum_iso[@]}
                        others_os_yum_iso[${array_length} + 1]=${file_name}
                    fi
                fi
            fi
        done
    else
        echo -e "\033[31m [${base_directory}] directory is empty, operation cannot be performed.\033[0m"
        return 1
    fi
    # 检查当前操作系统类型的ISO文件是否找到
    if [ "${current_os_yum_iso}" == "" ]; then
        echo -e "\033[49;31m [${base_directory}] directory yum iso file does not exist.\033[0m"
        error_flag=1
    fi

    if [ ! -f "${base_directory}.sshpass" ]; then
        echo -e "\033[49;31m [${base_directory}.sshpass] file does not exist.\033[0m"
        error_flag=1
    fi

    if [ ! -f "${base_directory}hostname.csv" ]; then
        echo -e "\033[49;31m [${base_directory}hostname.csv] file does not exist.\033[0m"
        error_flag=1
    fi

    if [ "${error_flag}" == "1" ]; then
        return 1
    fi
}

# 安装配置nfs客户端
# ${1}参数说明: 传入的服务端IP地址
function init_setup_nfs_client() {
    # 安装依赖的服务
    setup_nfs_dependent
    # 启动服务
    systemctl enable rpcbind.service && systemctl start rpcbind.service
    # 检查并创建客户端共享目录
    for share_dir in ${share_directories}; do
        if [ ! -d "${share_dir}/" ]; then
            mkdir -m 755 -p ${share_dir}/
        fi
        # 挂载共享目录
        mount -t nfs ${1}:${share_dir}
    done
}

# 主函数入口
function main() {
    # 服务端客户端标识
    is_server=${1}
    if [[ -z ${is_server} ]]; then
        is_server=true
    fi

    if [ "${is_server}" == "true" ]; then
        # 检查校验执行初始化脚本的合法性
        init_verify
        if [ "$?" == "1" ]; then
            exit 1
        fi
        init_mount_yum
        init_close_firewall
        init_create_dir
        init_setup_nfs_server
        init_sync_file_to_client
    else
        init_create_dir
        init_close_firewall
        init_setup_nfs_client ${2}
    fi
}

main ${1} ${2}
