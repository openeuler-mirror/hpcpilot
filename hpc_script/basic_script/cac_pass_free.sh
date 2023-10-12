#
# Copyright (c) Huawei Technologies Co., Ltd. 2022-2022. All rights reserved.
#

#!/usr/bin/env bash
######################################################################
# 脚本描述：双向免密配置自动化脚本                                          #
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

# 当前主机IP地址
current_ip_addr=$(get_current_host_ip)

# 使用SSHPASS和SCP工具将运维节点生成的.ssh整个文件夹复制到其它所有节点
# 注意：当前方法未使用，暂时保留。目前使用ANSIBLE工具将运维节点生成的.ssh
#      复制到其它所有节点
function sync_sshkey() {
    # ret_code值为0表示hostname.csv文件存在，值为1表示hostname.csv文件不存在
    local ret_code=0
    # unconnected 未联通的IP地址
    local unconnected=""
    if [ $(is_file_exist ${hostname_file}) = 0 ]; then
        # tail -n +2 从第二行开始读取数据，第一行为标题行
        for line in $(cat ${hostname_file} | tail -n +2); do
            # 检查判断字符串长度是否为0
            if [ -n "${line}" ]; then
                local ip_addr=$(echo ${line} | awk -F "," '{print $1}')
                if [ -n "${ip_addr}" ] && [ "${ip_addr}" != "${om_machine_ip}" ]; then
                    # 检查主机的连通性
                    ping -c 1 ${ip_addr} 1>/dev/null 2>/dev/null
                    if [ $? -eq 0 ]; then
                        # 第一次连接需要打通IP，否则需要输入密码验证
                        sshpass -f /root/.sshpass ssh -o StrictHostKeyChecking=no root@${ip_addr} 'echo ""' 1>/dev/null 2>/dev/null
                        # 复制/root/.ssh/文件夹到目录节点
                        sshpass -f /root/.sshpass scp -r /root/.ssh/ root@${ip_addr}:/root/ 1>/dev/null 2>/dev/null
                        # 赋予远程文件id_rsa.pub脚本权限
                        sshpass -f /root/.sshpass ssh root@${ip_addr} "chmod 600 /root/.ssh" 1>/dev/null 2>/dev/null
                        sshpass -f /root/.sshpass ssh root@${ip_addr} "chmod 600 /root/.ssh/id_rsa.pub" 1>/dev/null 2>/dev/null
                        if [ $? -eq 0 ];then
                            log_info "Node [${ip_addr}] synchronization succeeded." false 
                        else
                            log_error "Node [${ip_addr}] synchronization failed." false 
                            unconnected="${unconnected}\n${ip_addr}"
                        fi
                    else
                        unconnected="${unconnected}\n${ip_addr}"
                    fi
                fi
            fi
        done
        log_error "Synchronization failed nodes : ${unconnected}" false
    else
        log_error "[${hostname_file}] file doesn't exist." false
        ret_code=1
    fi
    local ret_info=(${ret_code} ${unconnected})
    echo ${ret_info[@]}
}

# 双向免密配置检查
function check_pass_free() {
    local ret_om_code="0"
    local ret_sshpass_code="0"
    local ret_id_rsa_file="0"
    local ret_id_rsa_pub_file="0"
    if [[ -n "$(echo "${current_ip_addr}" | grep "${om_machine_ip}")" ]]; then
        ret_om_code="1"
        if [ "$(rpm -qa sshpass)" == "" ]; then
            ret_sshpass_code="1"
        fi
        if [ $(is_file_exist /root/.ssh/id_rsa) != 0 ]; then
            ret_id_rsa_file="1"
        fi
        if [ $(is_file_exist /root/.ssh/id_rsa.pub) != 0 ]; then
            ret_id_rsa_pub_file="1"
        fi
    else
        if [ $(is_file_exist /root/.ssh/id_rsa.pub) != 0 ]; then
            ret_id_rsa_pub_file="1"
        fi
    fi
    local ret_info=(${ret_om_code} ${ret_sshpass_code} ${ret_id_rsa_file} ${ret_id_rsa_pub_file})
    echo ${ret_info[@]}
}

# 免密配置检查结果打印输出
function check_pass_free_result() {
    echo -e ""
    echo -e "\033[33m==================[5]计算节点免密配置检查结果=============================\033[0m"
    return_msg=($(check_pass_free))
    if [ "${return_msg[0]}" == "1" ]; then
        # OM 节点
        if [ "${return_msg[1]}" == "0" ]; then
            echo -e "\033[33m==\033[0m\033[32m  sshpass服务安装配置正常                              [ √ ]\033[0m          \033[33m==\033[0m"
        else
            echo -e "\033[33m==\033[0m\033[31m  sshpass服务未安装或配置异常                          [ X ]\033[0m          \033[33m==\033[0m"
        fi
        if [ "${return_msg[2]}" == "0" ]; then
            echo -e "\033[33m==\033[0m\033[32m  配置文件[/root/.ssh/id_rsa]配置正常                  [ √ ]\033[0m          \033[33m==\033[0m"
        else
            echo -e "\033[33m==\033[0m\033[31m  配置文件[/root/.ssh/id_rsa]不存在或配置异常          [ X ]\033[0m          \033[33m==\033[0m"
        fi
        if [ "${return_msg[3]}" == "0" ]; then
            echo -e "\033[33m==\033[0m\033[32m  配置文件[/root/.ssh/id_rsa.pub]配置正常              [ √ ]\033[0m          \033[33m==\033[0m"
        else
            echo -e "\033[33m==\033[0m\033[31m  配置文件[/root/.ssh/id_rsa.pub]不存在或配置异常      [ X ]\033[0m          \033[33m==\033[0m"
        fi
    else
        # 非O&M节点
        if [ "${return_msg[3]}" == "0" ]; then
            echo -e "\033[33m==\033[0m\033[32m  配置文件[/root/.ssh/id_rsa.pub]配置正常              [ √ ]\033[0m          \033[33m==\033[0m"
        else
            echo -e "\033[33m==\033[0m\033[31m  配置文件[/root/.ssh/id_rsa.pub]不存在或配置异常      [ X ]\033[0m          \033[33m==\033[0m"
        fi
    fi
    echo -e "\033[33m==================[5]计算节点免密配置检查结果=============================\033[0m"
}

# 配置免密配置
function config_pass_free() {
    local ret_om_code=1
    # 判断当前机器是否是运维节点
    if [ -n "$(echo "${current_ip_addr}" | grep "${om_machine_ip}")" ]; then
        # 检查服务是否安装启动
        if [ "$(rpm -qa sshpass)" == "" ]; then
            # 安装依赖的sshpass服务
            if [ "$(yum list | grep sshpass)" != "" ]; then
                yum install -y sshpass >> ${operation_log_path}/access_all.log 2>&1
            else
                if [ -z "$(find_file_by_path ${sourcecode_dir}/ansible/ sshpass rpm)" ]; then
                    log_error "Sshpass dependency package doesn't exist, password-free cannot be configured." false
                else
                    cd ${sourcecode_dir}/ansible/
                    yum install -y sshpass >> ${operation_log_path}/access_all.log 2>&1
                fi
            fi
        fi
        if [ "$(rpm -qa sshpass)" != "" ]; then
            log_info "Sshpass service installation succeeded." false
            # 同步生成的sshkey文件到其它节点
            local ret_sync_code=($(sync_sshkey))
        else
            log_error "Sshpass dependency package doesn't exist, password-free cannot be configured." false
        fi
    else
        ret_om_code=0
        local ret_sync_code=("" "")
    fi
    local ret_info=(${ret_om_code} ${ret_sync_code[1]})
    echo ${ret_info[@]}
}

# 免密配置结果打印输出
function config_pass_free_result() {
    config_pass_free
    check_pass_free_result
}

# 脚本执行合法性检查
function required_check() {
    if [ $(is_file_exist ${hostname_file}) == "1" ]; then
        log_error "[${hostname_file}] file doesn't exist, please check." false
        return 1
    fi
    # 运维节点OM配置检查
    if [ -z "${om_machine_ip}" ]; then
        log_error "Ip address of the O&M node is not configured, please check." false
        return 1
    fi
    # 检查sshpass是否存在或者安装
    yum list 1>/dev/null 2>/dev/null
    # 如果未配置yum源不做sshpass安装文件检查
    if [ $? -eq 1 ]; then
        return 0
    fi
    if [ -z "$(yum list | grep sshpass)" ] && [ "$(rpm -qa sshpass)" == "" ]; then
        # 如果yum源中没有找到再从sourcecode软件包中去找
        local sshpass_rpm=$(find_file_by_path ${sourcecode_dir}/ansible/ sshpass rpm)
        if [ -z "${sshpass_rpm}" ]; then
            log_error "Sshpass dependency package doesn't exist, please check." false
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
manual_script_action ${is_manual_script} ${is_open_debug} required_check check_pass_free_result config_pass_free_result ${4}
