#!/usr/bin/env bash
# 安装ANSIBLE自动化配置管理工具自动化脚本

# 引用公共函数文件开始
source /${3}/software/tools/hpc_script/common.sh ${3}
# 引用公共函数文件结束

# 软件存放路径地址
sourcecode_dir=$(get_sourcecode_dir)
# 配置文件路径
hostname_file=$(get_ini_value basic_conf basic_shared_directory /share)/software/tools/hpc_script/hostname.csv
# 获取运维节点机器IP地址
is_om_machine=$(get_ini_value basic_conf basic_om_master_ip)
# 获取IP分组信息
ip_group_array=($(get_ini_value basic_conf basic_node_ip_group))
# 当前主机IP地址
current_ip_addr=$(get_current_host_ip)
# ansible版本号
ansible_version=""
# 计算节点用户名root密码
ssh_user_password=$(get_ini_value common_global_conf common_sys_root_password "huawei@123")

# 读取文件并生成/etc/hosts文件
function create_etc_hosts() {
    if [ "$(is_file_exist ${hostname_file})" == "0" ]; then
        local hosts_content="127.0.0.1   localhost localhost.localdomain localhost4 localhost4.localdomain4\n::1         localhost localhost.localdomain localhost6 localhost6.localdomain6\n"
        # tail -n +2 从第二行开始读取数据，第一行为标题行
        for line in $(cat ${hostname_file} | tail -n +2); do
            # 检查判断字符串长度是否为0
            if [ -n "${line}" ]; then
                local file_host_ip=$(echo ${line} | awk -F "," '{print $1}')
                local file_host_name=$(echo ${line} | awk -F "," '{print $2}')
                hosts_content="${hosts_content}${file_host_ip} ${file_host_name}\n"
            fi
        done
        # 覆盖写入/etc/hosts文件
        echo -ne "${hosts_content}" >/etc/hosts
    else
        log_error "$(get_current_host_info)_${hostname_file} file doesn't exist." false
    fi
}

# 读取文件并进行写入ansible host配置文件
function read_hostname_file() {
    if [ "$(is_file_exist ${hostname_file})" == "0" ]; then
        # TODO 20230307_如需有时间则将下面变量改为动态获取，目前由于技术原因无法实现。
        local ccsccp=""
        local agent_ip=""
        local scheduler_ip=""
        local portal_ip=""
        local cli_ip=""
        local ntp_server_ip=""
        local ntp_client_ip=""
        local ldap_client_ip=""
        # tail -n +2 从第二行开始读取数据，第一行为标题行
        for line in $(cat ${hostname_file} | tail -n +2); do
            # 检查判断字符串长度是否为0
            if [ -n "${line}" ]; then
                local file_host_ip=$(echo ${line} | awk -F "," '{print $1}')
                # 剔除OM运维节点IP地址
                if [ "${file_host_ip}" != "${is_om_machine}" ]; then
                    local group_name="$(echo ${line} | awk -F "," '{print $3}')"
                    if [ -n "${group_name}" ]; then
                        if [[ "${group_name}" =~ "csp" ]]; then
                            if [ -z "${ccsccp}" ]; then
                                ccsccp="$(echo ${line} | awk -F "," '{print $1}') ansible_ssh_user=root ansible_ssh_pass=${ssh_user_password}"
                            else
                                ccsccp="${ccsccp}\n$(echo ${line} | awk -F "," '{print $1}') ansible_ssh_user=root ansible_ssh_pass=${ssh_user_password}"
                            fi
                        fi
                        if [[ "${group_name}" =~ "agent" ]]; then
                            if [ -z "${agent_ip}" ]; then
                                agent_ip="$(echo ${line} | awk -F "," '{print $1}') ansible_ssh_user=root ansible_ssh_pass=${ssh_user_password}"
                            else
                                agent_ip="${agent_ip}\n$(echo ${line} | awk -F "," '{print $1}') ansible_ssh_user=root ansible_ssh_pass=${ssh_user_password}"
                            fi
                        fi
                        if [[ "${group_name}" =~ "ccs" ]]; then
                            if [ -z "${scheduler_ip}" ]; then
                                scheduler_ip="$(echo ${line} | awk -F "," '{print $1}') ansible_ssh_user=root ansible_ssh_pass=${ssh_user_password}"
                            else
                                scheduler_ip="${scheduler_ip}\n$(echo ${line} | awk -F "," '{print $1}') ansible_ssh_user=root ansible_ssh_pass=${ssh_user_password}"
                            fi
                        fi
                        if [[ "${group_name}" =~ "ccp" ]]; then
                            if [ -z "${portal_ip}" ]; then
                                portal_ip="$(echo ${line} | awk -F "," '{print $1}') ansible_ssh_user=root ansible_ssh_pass=${ssh_user_password}"
                            else
                                portal_ip="${portal_ip}\n$(echo ${line} | awk -F "," '{print $1}') ansible_ssh_user=root ansible_ssh_pass=${ssh_user_password}"
                            fi
                        fi
                        if [[ "${group_name}" =~ "cli" ]]; then
                            if [ -z "${cli_ip}" ]; then
                                cli_ip="$(echo ${line} | awk -F "," '{print $1}') ansible_ssh_user=root ansible_ssh_pass=${ssh_user_password}"
                            else
                                cli_ip="${cli_ip}\n$(echo ${line} | awk -F "," '{print $1}') ansible_ssh_user=root ansible_ssh_pass=${ssh_user_password}"
                            fi
                        fi
                        if [[ "${group_name}" =~ "ntp_server" ]]; then
                            if [ -z "${ntp_server_ip}" ]; then
                                ntp_server_ip="$(echo ${line} | awk -F "," '{print $1}') ansible_ssh_user=root ansible_ssh_pass=${ssh_user_password}"
                            else
                                ntp_server_ip="${ntp_server_ip}\n$(echo ${line} | awk -F "," '{print $1}') ansible_ssh_user=root ansible_ssh_pass=${ssh_user_password}"
                            fi
                        fi
                        if [[ "${group_name}" =~ "ntp_client" ]]; then
                            if [ -z "${ntp_client_ip}" ]; then
                                ntp_client_ip="$(echo ${line} | awk -F "," '{print $1}') ansible_ssh_user=root ansible_ssh_pass=${ssh_user_password}"
                            else
                                ntp_client_ip="${ntp_client_ip}\n$(echo ${line} | awk -F "," '{print $1}') ansible_ssh_user=root ansible_ssh_pass=${ssh_user_password}"
                            fi
                        fi   
                        if [[ "${group_name}" =~ "ldap_client" ]]; then
                            if [ -z "${ldap_client_ip}" ]; then
                                ldap_client_ip="$(echo ${line} | awk -F "," '{print $1}') ansible_ssh_user=root ansible_ssh_pass=${ssh_user_password}"
                            else
                                ldap_client_ip="${ldap_client_ip}\n$(echo ${line} | awk -F "," '{print $1}') ansible_ssh_user=root ansible_ssh_pass=${ssh_user_password}"
                            fi
                        fi
                    fi  
                fi
            fi
        done
        # 追加写入/etc/ansible/hosts文件
        echo -ne "[ccsccp]\n" >>/etc/ansible/hosts
        echo -ne "${ccsccp}" >>/etc/ansible/hosts
        echo -ne "\n[agent]\n" >>/etc/ansible/hosts
        echo -ne "${agent_ip}" >>/etc/ansible/hosts
        echo -ne "\n[scheduler]\n" >>/etc/ansible/hosts
        echo -ne "${scheduler_ip}" >>/etc/ansible/hosts
        echo -ne "\n[portal]\n" >>/etc/ansible/hosts
        echo -ne "${portal_ip}" >>/etc/ansible/hosts
        echo -ne "\n[cli]\n" >>/etc/ansible/hosts
        echo -ne "${cli_ip}" >>/etc/ansible/hosts
        echo -ne "\n[ntp_server]\n" >>/etc/ansible/hosts
        echo -ne "${ntp_server_ip}" >>/etc/ansible/hosts
        echo -ne "\n[ntp_client]\n" >>/etc/ansible/hosts
        echo -ne "${ntp_client_ip}" >>/etc/ansible/hosts
        echo -ne "\n[ldap_client]\n" >>/etc/ansible/hosts
        echo -ne "${ldap_client_ip}" >>/etc/ansible/hosts
    else
        log_error "$(get_current_host_info)_${hostname_file} file doesn't exist." false
    fi
}

# 检查ansible安装配置是否OK
function check_setup_ansible() {
    local ret_install_code="0"
    local ret_cfg_code="0"
    local ret_host_code="0"
    local is_install_succeed=$(rpm -qa ansible)
    if [ "${is_om_machine}" == "${current_ip_addr}" ]; then
        if [ "${is_install_succeed}" == "" ]; then
            ret_install_code="1"
            echo ${ret_install_code}
        else
            # 检查ansible.cfg文件配置
            local result=$(cat /etc/ansible/ansible.cfg | grep "#host_key_checking")
            if [ "${result}" != "" ]; then
                ret_cfg_code="1"
            fi
            # 检查host文件配置是否正确
            # TODO 20230112_目前ansible host文件配置检查简单，后续深入优化
            local result1=$(cat /etc/ansible/hosts | grep -w "ccsccp")
            if [ "${result1}" == "" ]; then
                ret_host_code="1"
            fi
            # 获取ansible版本号
            ansible_version=$(ansible --version | awk '{print $2}'  | sed -n '1P')
            
            local ret_info=(${ret_install_code} ${ret_cfg_code} ${ret_host_code})
            echo ${ret_info[@]}  
        fi
    else
        ret_install_code="0"
        echo ${ret_install_code}
    fi
}

# 检查ansible安装配置是否OK打印输出
function check_setup_ansible_result() {
    echo -e ""
    echo -e "\033[33m==================[2]ANSIBLE安装检查结果==================================\033[0m"
    local return_msg=($(check_setup_ansible))
    if [ "${is_om_machine}" == "${current_ip_addr}" ]; then
        # 运维节点检查结果显示
        if [ "${return_msg[0]}" == "0" ]; then
            echo -e "\033[33m==\033[0m\033[32m  ANSIBLE安装检查结果正常                              [ √ ]\033[0m          \033[33m==\033[0m"
            echo -e "\033[33m==\033[0m\033[32m  ANSIBLE软件当前版本为：$(ansible --version | awk '{print $2}'  | sed -n '1P')\033[0m                                        \033[33m==\033[0m"
            if [ "${return_msg[1]}" == "0" ]; then
                echo -e "\033[33m==\033[0m\033[32m  [/etc/ansible/ansible.cfg]文件配置正确               [ √ ]\033[0m          \033[33m==\033[0m"
            else
                echo -e "\033[33m==\033[0m\033[31m  [/etc/ansible/ansible.cfg]文件未配置或配置不正确     [ X ]\033[0m          \033[33m==\033[0m"
            fi
            if [ "${return_msg[2]}" == "0" ]; then
                echo -e "\033[33m==\033[0m\033[32m  [/etc/ansible/hosts]文件配置正确                     [ √ ]\033[0m          \033[33m==\033[0m"
            else
                echo -e "\033[33m==\033[0m\033[31m  [/etc/ansible/hosts]文件未配置或配置不正确           [ X ]\033[0m          \033[33m==\033[0m"
            fi
        else
            echo -e "\033[33m==\033[0m\033[31m  ANSIBLE软件当前未安装                                [ X ]\033[0m          \033[33m==\033[0m"
        fi  
    else
        # 非运维节点
        echo -e "\033[33m==\033[0m\033[32m  非运维节点无需安装ANSIBLE软件                        [ √ ]\033[0m          \033[33m==\033[0m"
    fi
    echo -e "\033[33m==================[2]ANSIBLE安装检查结果==================================\033[0m"
}

# 检查ansible文件是否存在
# 判断依据是如果文件名包含ansible且后缀名为.rpm即为当前需要安装的ansible文件
# 或者文件名以ansible_操作系统英文名称开头的文件即为当前需要安装的ansible文件
# 操作系统前缀名称，比如：CentOS、openEuler、Kylin
# 返回值为""不存在，否则返回ansible文件名
function find_ansible_file() {
    local ansible_file_name=""
    # 当前操作系统名称
    local current_os_info=($(cat /etc/system-release))
    cd ${sourcecode_dir}/ansible/
    local files=$(ls ${sourcecode_dir}/ansible/)
    for file_name in ${files}; do
        if [[ "${file_name}" =~ ^"ansible_${current_os_info[0]}"* ]]; then
            ansible_file_name=${file_name}
            break
        fi
        if [[ "${file_name}" =~ "ansible" ]] && [ "${file_name##*.}" == "rpm" ]; then
            ansible_file_name=${file_name}
            break
        fi
    done
    echo ${ansible_file_name}
}

# 安装配置ansible
function setup_and_config_ansible() {
    # 判断当前机器是否是运维节点
    local ansible_file_name=""
    if [ "${is_om_machine}" == "${current_ip_addr}" ]; then
        # 检查ANSIBLE是否已安装，已安装先卸载
        if [ "$(rpm -qa ansible)" != "" ]; then
            yum remove -y ansible &>/dev/null
        fi
        # 安装ANSIBLE
        if [ "$(yum list | grep ansible)" == "" ]; then
            # 使用本地安装方式安装
            cd ${sourcecode_dir}/ansible/
            if [ "$(find_ansible_file)" != "" ]; then
                # 目前本地安装支持 1.麒麟V10_ARM64版本、2.CENTOS7.6_ARM64版本
                yum localinstall -y *.rpm &>/dev/null
            else
                log_error "$(get_current_host_info)_[${sourcecode_dir}/ansible/] the ansible file is not found." false
            fi
        else
            # 使用YUM源安装，当前只适用欧拉系统
            yum install -y ansible 1>/dev/null 2>/dev/null
        fi
        # 检查安装是否成功
        if [ "$(ansible --version)" != "" ]; then
            ansible_version=$(ansible --version | awk '{print $2}'  | sed -n '1P')
            log_info "$(get_current_host_info)_ansible service installation succeeded." false
        fi
        ############## 进行ansible配置 ##############
        # 1.找到host_key_checking = False取消注释。该步骤为取消主机间初次ssh跳转的人机交互。
        remove_match_line_symbol /etc/ansible/ansible.cfg host_key_checking
        # 2.按照需要将目标节点ip分配到不同的组，写入文件（支持正则）
        read_hostname_file
        # TODO 20230119_需要提供ANSIBLE验证是否配置成功的方法
    fi
    # 按照需要将目标节点ip和hostname写入到/etc/hosts文件中
    create_etc_hosts
}

# ANSIBLE安装部署结果输出打印
function setup_and_config_ansible_result() {
    echo -e ""
    echo -e "\033[33m==================[2]ANSIBLE安装部署开始==================================\033[0m"
    # 调用安装配置ANSIBLE方法
    setup_and_config_ansible
    # 调用ANSIBLE检查的方法
    local return_msg=($(check_setup_ansible))
    if [ "${is_om_machine}" == "${current_ip_addr}" ]; then
        # 运维节点安装检查结果
        if [ "${return_msg[0]}" == "0" ]; then
            echo -e "\033[33m==\033[0m\033[32m  ANSIBLE安装部署成功                                  [ √ ]\033[0m          \033[33m==\033[0m"
            echo -e "\033[33m==\033[0m\033[32m  ANSIBLE软件当前版本为：${ansible_version}\033[0m                                        \033[33m==\033[0m"
            if [ "${return_msg[1]}" == "0" ]; then
                echo -e "\033[33m==\033[0m\033[32m  [/etc/ansible/ansible.cfg]文件配置正确               [ √ ]\033[0m          \033[33m==\033[0m"
            else
                echo -e "\033[33m==\033[0m\033[31m  [/etc/ansible/ansible.cfg]文件未配置或配置不正确     [ X ]\033[0m          \033[33m==\033[0m"
            fi
            if [ "${return_msg[2]}" == "0" ]; then
                echo -e "\033[33m==\033[0m\033[32m  [/etc/ansible/hosts]文件配置正确                     [ √ ]\033[0m          \033[33m==\033[0m"
            else
                echo -e "\033[33m==\033[0m\033[31m  [/etc/ansible/hosts]文件未配置或配置不正确           [ X ]\033[0m          \033[33m==\033[0m"
            fi
        else
            echo -e "\033[33m==\033[0m\033[31m  ANSIBLE安装部署失败                                  [ X ]\033[0m          \033[33m==\033[0m"
        fi
    else
        # 非运维节点安装检查结果
        echo -e "\033[33m==\033[0m\033[32m  非运维节点无需安装ANSIBLE软件                        [ √ ]\033[0m          \033[33m==\033[0m"
    fi
    echo -e "\033[33m==================[2]ANSIBLE安装部署结束==================================\033[0m"
}

# 脚本执行合法性检查
function required_check() {
    # 运维节点OM配置检查
    if [ -z "${is_om_machine}" ]; then
        echo -e "\033[31m ip address of the om node is not configured, system exit.\033[0m"
        return 1
    fi
    # 检查ANSIBLE是否可以安装
    if [ "${is_om_machine}" == "${current_ip_addr}" ]; then
        if [ $(is_file_exist ${hostname_file}) == "1" ]; then
            echo -e "\033[31m [${hostname_file}] file does not exist, system exit.\033[0m"
            return 1
        fi
        if [ "$(rpm -qa ansible)" == "" ]; then
            if [ "$(yum list | grep ansible)" == "" ]; then
                # 使用本地安装方式安装(检查本地ANSIBLE文件是否存在)
                if [ "$(find_ansible_file)" == "" ]; then
                    echo -e "\033[31m [${sourcecode_dir}/ansible/] ansible installation files does not exist, system exit.\033[0m"
                    result 1
                fi
            fi
        fi
    fi
}

############### 主函数入口 ###############
# 参数${1}表示手动执行脚本还是自动执行脚本方式
# 参数${2}是否开启DEBUG模式
is_manual_script=${1}
is_open_debug=${2}
if [ -z "${is_manual_script}" ]; then
    is_manual_script=true
fi
if [ -z "${is_open_debug}" ]; then
    is_open_debug=false
fi
manual_script_action ${is_manual_script} ${is_open_debug} required_check check_setup_ansible_result setup_and_config_ansible_result