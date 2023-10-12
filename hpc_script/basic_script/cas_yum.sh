# Copyright (c) Huawei Technologies Co., Ltd. 2022-2022. All rights reserved.
#

#!/usr/bin/env bash
######################################################################
# 脚本描述：运维节点挂载本地YUM源和创建本地网络源自动化脚本                      #
# 注意事项：无                                                          #
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

# YUM镜像文件名
yum_iso_file_name=""
# YUM镜像安装挂载路径
yum_install_path=$(readlink -f "$(get_ini_value basic_conf basic_yum_install_path mnt)")
# 获取当前主机IP地址（无法使用ifconfig命令情况下）
current_ip_addr=$(ip addr | awk '/^[0-9]+: / {}; /inet.*global/ {print gensub(/(.*)\/(.*)/, "\\1", "g", $2)}')

# 检查配置文件/etc/yum.repos.d/local.repo是否配置正确
# 返回0表示配置正确，1表示配置不正确
function check_local_repo() {
    local var1
    if [ -n "$(cat /etc/system-release | grep "CentOS Linux release 8.2.2004")" ]; then
        var1=$(grep "name=centos-" /etc/yum.repos.d/local.repo)
    else
        var1=$(grep "name=local" /etc/yum.repos.d/local.repo)
    fi
    local var2=$(grep "baseurl=file://${yum_install_path}/" /etc/yum.repos.d/local.repo)
    local var3=$(grep "enabled=1" /etc/yum.repos.d/local.repo)
    local var4=$(grep "gpgcheck=0" /etc/yum.repos.d/local.repo)
    if [ -z "${var1}" ] || [ -z "${var2}" ] || [ -z "${var3}" ] || [ -z "${var4}" ]; then
        echo 1
    else
        echo 0
    fi
}

# 检查某个目录下文件是否存在某个文件
# 判断依据是如果文件名包含关键字且后缀名为指定的后缀名即为当前需要查找的文件
# 或者文件名以关键字_操作系统英文名称开头的文件即为当前需要需要查找的文件
# 操作系统前缀名称，比如：CentOS、openEuler、Kylin
# 在文件夹中找到ISO YUM源
# 不支持文件夹中有多个相同类型（X86 ARM64）操作系统ISO
# ${1}=sourcecode目录
function find_os_yum() {
    # 当前操作系统名称
    local current_os_info=($(cat /etc/system-release))
    ############### 遍历文件夹下所有ISO文件并查找当前系统对应的ISO ###############
    local files=$(ls ${1})
    if [ -n "${files}" ]; then
        for file_name in ${files}; do
            # 判断字符串是否以XXX字符串开头
            if [[ "${file_name}" =~ ^"yum_${current_os_info[0]}"* ]]; then
                yum_iso_file_name=${file_name}
                break
            fi
            if [ "${file_name##*.}" == "iso" ] && [[ "${file_name}" =~ "${current_os_info[0]}" ]]; then
                yum_iso_file_name=${file_name}
                break
            fi
        done  
    else
        log_error "[${1}] directory is empty." false
    fi
    # 检查当前操作系统类型的ISO文件是否找到
    if [ "${yum_iso_file_name}" == "" ]; then
        log_error "Current system [${current_os_info[0]}] iso file is not found." false
    fi
}

# 检查yum安装配置是否正确
function check_yum_server() {
    # 定义返回结果 0=本地已挂载 1=未挂载 2=已挂载网络源
    local ret_code_mount="0"
    # 定义返回配置开机自动加载 0=已配置 1=未配置
    local ret_code_auto_start="0"
    # 检查*.repo文件配置是否正确 0=正确 1=不正确
    local ret_repo_code=0
    
    # 获取ISO文件
    find_os_yum ${sourcecode_dir}
    
    # 判断是否配置了网络YUM源
    local repo_file_name=$(find_file_by_path /etc/yum.repos.d/ http-local repo)
    if [ -z "${repo_file_name}" ]; then
        log_error "[/etc/yum.repos.d/] *.repo file is not found." false
    else
        if [ -n "$(cat /etc/yum.repos.d/${repo_file_name} | grep "http://${om_machine_ip}")" ]; then
            ret_code_mount=2
            log_info "Yum network source is configured on the current node." false
        fi  
    fi
    
    # 如果配置网络源则不进行开机自动加载等其它项检查
    if [ "${ret_code_mount}" != "2" ]; then
        # 检查是否挂载YUM源
        if [ "$(df -Th | grep -o "iso9660")" != "iso9660" ]; then
            ret_code_mount="1"
        fi
        # 检查是否配置开机自启动
        local old_content=$(tail /etc/rc.d/rc.local)
        # 字符之间的空格不能随意删减
        local modify_content="mount -t iso9660 -o loop"
        if [[ "${old_content}" =~ "${modify_content}" ]]; then
            ret_code_auto_start="0"
        else
            ret_code_auto_start="1"
        fi
        ############### /etc/yum.repos.d/local.repo文件配置检查 ###############
        if [ "$(check_local_repo)" == "1" ]; then
            ret_repo_code=1
        fi 
    fi
    ret_info=(${ret_code_mount} ${ret_code_auto_start} ${ret_repo_code})
    echo ${ret_info[@]}
}

function check_yum_result() {
    echo -e ""
    echo -e "\033[33m==================[1]节点YUM源挂载检查结果================================\033[0m"
    return_msg=($(check_yum_server))
    if [ "${return_msg[0]}" == "2" ]; then
        echo -e "\033[33m==\033[0m\033[32m  当前节点YUM源已配置网络源                            [ √ ]\033[0m          \033[33m==\033[0m"
    else
        if [ "${return_msg[0]}" == "0" ]; then
        echo -e "\033[33m==\033[0m\033[32m  节点YUM源已挂载                                      [ √ ]\033[0m          \033[33m==\033[0m"
        else
            echo -e "\033[33m==\033[0m\033[31m  节点YUM源未挂载                                      [ X ]\033[0m          \033[33m==\033[0m"
        fi
        if [ "${return_msg[1]}" == "0" ]; then
            echo -e "\033[33m==\033[0m\033[32m  节点YUM源开机自动挂载已配置                          [ √ ]\033[0m          \033[33m==\033[0m"
        else
            echo -e "\033[33m==\033[0m\033[31m  节点YUM源开机自动挂载未配置                          [ X ]\033[0m          \033[33m==\033[0m"
        fi
        if [ "${return_msg[2]}" == "0" ]; then
            echo -e "\033[33m==\033[0m\033[32m  [/etc/yum.repos.d/local.repo]文件配置检查正常        [ √ ]\033[0m          \033[33m==\033[0m"
        else
            echo -e "\033[33m==\033[0m\033[31m  [/etc/yum.repos.d/local.repo]文件配置检查异常        [ X ]\033[0m          \033[33m==\033[0m"
        fi  
    fi
    echo -e "\033[33m==================[1]节点YUM源挂载检查结果================================\033[0m"
}

# 配置网络YUM源和开机自动启
# ${1}=sourcecode目录
# ${2}=hpc_script目录
# ${3}=镜像文件前缀名称，比如：CentOS、openEuler、Kylin
function config_network_yum() {
    # 1.检查安装httpd服务
    if [ "$(rpm -qa httpd)" == "" ]; then
        yum install -y httpd >> ${operation_log_path}/access_all.log 2>&1
    fi
    systemctl enable httpd.service && systemctl start httpd.service
    if [ "$(systemctl status httpd.service | grep -o "active (running)")" == "" ]; then
        systemctl start httpd.service
    fi
    # 2.将镜像文件拷贝到http目录
    if [ -d "/var/www/html/${3}/" ]; then
        rm -rf /var/www/html/${3}/
    fi
    mkdir -p /var/www/html/${3}
    cp -rf ${yum_install_path}/* /var/www/html/${3}
    # 3.验证网络YUM源是否配置成功
    # 网络YUM源访问地址
    local yum_http_url=http://${om_machine_ip}/${3}
    local ret_code=$(curl -I -s --connect-timeout 1 ${yum_http_url}/ -w %{http_code} | tail -n1)
    if [ "x${ret_code}" == "x200" ]; then
        log_info "Network yum source is configured successfully." true
        local current_date=$(date '+%Y%m%d%H%M%S')
        log_info "Yum image source is mounted successfully, the yum configuration starts..." true
        log_info "Configuring cd-rom mounting for automatic startup upon system startup." true
        log_info "Backing up [/etc/rc.d/rc.local] file to [/etc/rc.d/rc.local.${current_date}.bak]." true
        # 4.备份开机自启动文件
        cp /etc/rc.d/rc.local /etc/rc.d/rc.local.${current_date}.bak
        # 5.设置配置开机自动挂载
        # 5.1判断是否存在之前已挂载的YUM自启动配置内容
        local line_nums=($(echo -n $(cat /etc/rc.d/rc.local | grep -n "mount -t iso9660 -o loop" | cut -d ":" -f 1)))
        if [ -n "${line_nums}" ]; then
            for (( i = 0; i < ${#line_nums[@]}; i++ )); do
                # 5.2删除之前配置的自启动配置内容
                sed -i "${line_nums[i]}d" /etc/rc.d/rc.local
            done
            # 5.3删除多余空白行
            sed -i /^[[:space:]]*$/d /etc/rc.d/rc.local
        fi
        if [[ "$(tail /etc/rc.d/rc.local)" =~ "mount -t iso9660 -o loop ${1}/${yum_iso_file_name} ${yum_install_path}" ]]; then
            log_info "Automatic mounting upon startup has been configured." true
        else
            # 5.4追加内容到配置文件中
            echo -ne "mount -t iso9660 -o loop ${1}/${yum_iso_file_name} ${yum_install_path}" >>/etc/rc.d/rc.local
        fi
        chmod +x /etc/rc.d/rc.local
        # 6.重新生成repo文件
        local http_repo_name=${2}/http-local.repo
        if [ -f "${http_repo_name}" ]; then
            rm -rf ${http_repo_name}
        fi
        if [ -n "$(cat /etc/system-release | grep 'CentOS Linux release 8.2.2004 (Core)')" ]; then
            echo -ne "[${3}-http-centos-BaseOS]\nname=${3}-http-centos-BaseOS\nbaseurl=${yum_http_url}/BaseOS/\nenabled=1\ngpgcheck=0\n\n" > ${http_repo_name}
            echo -ne "[${3}-http-centos-AppStream]\nname=${3}-http-centos-AppStream\nbaseurl=${yum_http_url}/AppStream/\nenabled=1\ngpgcheck=0\n\n" >> ${http_repo_name}
        else
            echo -ne "[${3}-http]\nname=${3}-http\nbaseurl=${yum_http_url}\nenabled=1\ngpgcheck=0\n\n" > ${http_repo_name}
        fi
    else
        log_info "Network yum source is not configured successfully, system exit." true
        exit 1
    fi
}

# 挂载安装配置本地YUM源
# ${1}=sourcecode目录
# ${2}=hpc_script目录
function mount_local_yum() {
    # 根据sourcecode目录查找ISO文件
    find_os_yum ${1}
    # 如果已挂载则先卸载（没有使用自动化挂载）
    # 目的是防止与自动化初始化脚本挂载方式不一致导致不可预知的问题
    yum list 1>/dev/null 2>/dev/null
    if [ $? -eq 0 ]; then
        yum list | grep vim 1>/dev/null 2>/dev/null
        if [ $? -eq 0 ] || [ "$(df -h | grep -o ${yum_install_path})" != "" ]; then
            umount -l ${yum_install_path}/
        fi
    fi
    # 1. 创建YUM源挂载路径
    if [ ! -d "${yum_install_path}/" ]; then
        mkdir -m 755 -p ${yum_install_path}/
    fi
    # 2. 挂载YUM镜像
    mount -t iso9660 -o loop ${1}/${yum_iso_file_name} ${yum_install_path} >> ${operation_log_path}/access_all.log 2>&1
    # 3. 检查是否挂载成功
    if [ -z "$(df -h | grep -o ${yum_install_path})" ]; then
        log_error "[${1}] mounting failed, check the mounting process." false
        exit 1
    else
        mount ${yum_install_path} >> ${operation_log_path}/access_all.log 2>&1
        if [ ! -d "/etc/yum.repos.bak/" ]; then
            mkdir -m 755 -p /etc/yum.repos.bak/
        fi
        # 4. 备份旧的repo配置文件
        mv -f /etc/yum.repos.d/* /etc/yum.repos.bak/
        # 4. 生成新的repo配置文件
        if [ -n "$(cat /etc/system-release | grep "CentOS Linux release 8.2.2004")" ]; then
            # 支持CentOS_V8.2
            echo -ne "[centos-BaseOS]\nname=centos-BaseOS\nbaseurl=file://${yum_install_path}/BaseOS/\nenabled=1\ngpgcheck=0\n\n" > /etc/yum.repos.d/local.repo
            echo -ne "[centos-AppStream]\nname=centos-AppStream\nbaseurl=file://${yum_install_path}/AppStream/\nenabled=1\ngpgcheck=0\n\n" >>/etc/yum.repos.d/local.repo
        else
            echo -ne "[local]\nname=local\nbaseurl=file://${yum_install_path}/\nenabled=1\ngpgcheck=0\n\n" >/etc/yum.repos.d/local.repo
        fi
        # 5. 清理和重新加载缓存
        yum clean all >> ${operation_log_path}/access_all.log 2>&1 && yum makecache >> ${operation_log_path}/access_all.log 2>&1
        # 6.配置网络YUM源和开机自动启
        # $(echo ${yum_iso_file_name%%-*})镜像文件前缀名称，比如：CentOS、openEuler、Kylin
        config_network_yum ${1} ${2} $(echo ${yum_iso_file_name%%-*})
        log_info "Local yum source mounted successfully." false
    fi
}

# 挂载计算节点网络源
# 方便测试提供从服务器copy配置好的CentOS-http.repo文件到本地,正常情况使用ANSIBLE
# 注意：该方法不对外提供
function mount_compute_yum() {
    if [ ! -d "/etc/yum.repos.bak/" ]; then
        mkdir -m 755 -p /etc/yum.repos.bak/
    fi
    # 备份旧的repo配置文件
    mv -f /etc/yum.repos.d/* /etc/yum.repos.bak/
    scp root@${om_machine_ip}:${base_directory}/http-local.repo /etc/yum.repos.d/
    # 5. 清理和重新加载缓存
    yum clean all >> ${operation_log_path}/access_all.log 2>&1 && yum makecache >> ${operation_log_path}/access_all.log 2>&1
}

# 挂载并检查自己节点YUM源
function mount_client_result() {
    mount_compute_yum
    basic_commands_install
    check_yum_result
}

# 挂载YUM源安装配置
# 运维节点挂载安装本地源并配置网络源
# 其它计算节点挂载网络源
# ${1}=true 表示挂载本地运维节点；false 表示不对运维节点操作。
# ${1} 参数主要区分用来手工操作时可单独挂载，自动化批量时由初始化操作。
function mount_yum_sources() {
    # 未安装YUM源无法使用ipconfig情况下获取当前主机IP地址
    # TODO 20230414_多网卡情况下未测试
    if [ -n "$(echo ${current_ip_addr} | grep "${om_machine_ip}")" ]; then
        # 运维节点
        mount_local_yum ${sourcecode_dir} ${base_directory}
    else
        # 计算节点
        mount_compute_yum
    fi
}

function mount_yum_result() {
    # 调用YUM挂载方法
    mount_yum_sources
    basic_commands_install
    check_yum_result
}

# 脚本执行合法性检查
function required_check() {
    # 运维节点OM配置检查
    if [ -z "${om_machine_ip}" ]; then
        log_error "Ip address of the OM node is not configured, system exit." true
        return 1
    fi
    if [ -n "$(echo ${current_ip_addr} | grep "${om_machine_ip}")" ]; then
        find_os_yum ${sourcecode_dir}
        # 检查运维节点
        if [ "${yum_iso_file_name}" == "" ]; then
            log_error "[${sourcecode_dir}] directory yum iso file does not exist, system exit." true
            return 1
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
manual_script_action ${is_manual_script} ${is_open_debug} required_check check_yum_result mount_yum_result ${4}