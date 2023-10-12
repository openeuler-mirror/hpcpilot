#
# Copyright (c) Huawei Technologies Co., Ltd. 2022-2022. All rights reserved.
#

#!/usr/bin/env bash
######################################################################
# 脚本描述：检查LDAP客户端状态自动化脚本                                       #
# 注意事项：无                                                          #
######################################################################

# 引用公共函数文件开始
if [ "${3}" == "opt" ]; then
    # 定义脚本文件、配置文件存放目录
    base_directory=/${3}/hpcpilot/hpc_script
else
    # 定义脚本文件、配置文件存放目录
    base_directory=/${3}/software/tools/hpc_script
fi
source ${base_directory}/common.sh ${3}
# 引用公共函数文件结束

# 获取配置文件LDAP服务端domain
ldap_domain_name=$(get_ini_value basic_conf ldap_domain_name)
# 获取配置文件ldap服务端主机名
master_ldap_server_ip=$(get_ini_value basic_conf master_ldap_server_ip)
# 获取本机ip
current_ip_addr=$(ip addr | awk '/^[0-9]+: / {}; /inet.*global/ {print gensub(/(.*)\/(.*)/, "\\1", "g", $2)}')

# ldap检查结果打印输出
function check_ldap_result() {
    echo -e ""
    echo -e "\033[33m==================[14]计算节点LDAP检查结果=====================\033[0m"
    if [ "${current_ip_addr}" == "${master_ldap_server_ip}" ]; then
       if [ "$(systemctl status slapd.service | grep -o "active (running)")" != "" ]; then
          echo -e "\033[33m==\033[0m\033[32m  LDAP服务端slapd.service服务已启动                     [ √ ]\033[0m          \033[33m==\033[0m"
          if [ "$(ldapsearch -x -b "dc=huawei,dc=com" -H ldaps://${ldap_domain_name}:636 |grep dn |grep "ldapDemo")" != "" ]; then
                  echo -e "\033[33m==\033[0m\033[32m  查询LDAP服务状态成功                                  [ √ ]\033[0m          \033[33m==\033[0m"
          else
                  echo -e "\033[33m==\033[0m\033[31m  查询LDAP服务状态失败                                  [ X ]\033[0m          \033[33m==\033[0m"
          fi
       else
          echo -e "\033[33m==\033[0m\033[31m  LDAP服务端slapd.service服务未启动                    [ X ]\033[0m          \033[33m==\033[0m"
       fi
    else
       if [ "$(systemctl status nslcd.service | grep -o "active (running)")" != "" ]; then
          echo -e "\033[33m==\033[0m\033[32m  LDAP客户端nslcd.service服务已启动                     [ √ ]\033[0m          \033[33m==\033[0m"
          if [ "$(ldapsearch -x -b "dc=huawei,dc=com" -H ldaps://${ldap_domain_name}:636 |grep dn |grep "ldapDemo")" != "" ]; then
                 echo -e "\033[33m==\033[0m\033[32m  LDAP客户端连接服务端成功                               [ √ ]\033[0m          \033[33m==\033[0m"
          else
                 echo -e "\033[33m==\033[0m\033[31m  LDAP客户端连接服务端失败                               [ X ]\033[0m          \033[33m==\033[0m"
          fi
       else
          echo -e "\033[33m==\033[0m\033[31m  LDAP客户端nslcd.service服务未启动                     [ X ]\033[0m          \033[33m==\033[0m"
       fi
    fi
    echo -e "\033[33m==================[14]计算节点LDAP检查结果=====================\033[0m"
}

# 脚本执行合法性检查，无检查项直接返回0
function required_check() {
    return 0
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
manual_script_action ${is_manual_script} ${is_open_debug} required_check check_ldap_result ${4}