#
# Copyright (c) Huawei Technologies Co., Ltd. 2022-2022. All rights reserved.
#

#!/usr/bin/env bash
######################################################################
# 脚本描述：批量创建DonauKit产品操作帐号业务用户自动化脚本                     #
# 注意事项：该脚本提供通过users.json文件和指定初始序列值两张方法创建，目前使用     #
#         users.json文件创建，初始序列值创建未启动。                        #
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

# userid序列初始值
user_id_init_sequence=$(get_ini_value basic_conf basic_userid_init_sequence 60000)
# 定义需要创建的业务用户
definition_business_users=(ccs_master ccs_agent ccs_ignite ccs_cli ccs_auth ccs_etcd postgres ccsuite hacluster ccp_master ccp_sysadmin ccp_secadmin ccp_audadmin hmpi_master hmpi_user)
# users.json文件存放路径
users_json_file=${base_directory}/users.json
# 业务用户密码
user_password=$(get_ini_value common_global_conf common_sys_user_password 'Huawei12#$123456')

# 使用userid序列初始值创建业务用户
function create_users_by_sequence() {
    local user_group_id=${user_id_init_sequence}
    local ccs_master_group_id
    for (( i = 0; i < ${#definition_business_users[@]}; i++ )); do
        local user_group_name=${definition_business_users[i]}
        if [ "${user_group_name}" == "ccp_master" ]; then
            # 因为ccs_master和ccp_master使用同一个groupid因此组名只创建一次
            useradd -u ${user_group_id} -g ${ccs_master_group_id} -d /home/${user_group_name} ${user_group_name}
            echo ${user_password} | sudo passwd --stdin ${user_group_name} >&/dev/null
        else
            if [ "${user_group_name}" == "ccs_master" ]; then
                 ccs_master_group_id=${user_group_id}
            fi
            # 新增用户组
            groupadd ${user_group_name} -g ${user_group_id}
            # 新增用户
            useradd -u ${user_group_id} -g ${user_group_id} -d /home/${user_group_name} ${user_group_name}
            echo ${user_password} | sudo passwd --stdin ${user_group_name} >&/dev/null
        fi
        user_group_id=$((${user_group_id}+1))
    done
    log_info "DonauKit product operation account has been created completely." false
}

# 检查业务用户创建是否正常是否完整
# 该方法提供给使用序列创建的用户检查方法
# 注意：目前未使用
function check_users_by_sequence() {
    # 记录未创建的用户名称
    local uncreated_users
    for (( i = 0; i < ${#definition_business_users[@]}; i++ )); do
        local user_group_name=${definition_business_users[i]}
        if [ -z "$(egrep ${user_group_name} /etc/passwd)" ]; then
            uncreated_users="${uncreated_users}${user_group_name}\n"
        fi
    done
    echo ${uncreated_users}
}

# 检查业务用户创建是否正常是否完整
# 该方法提供给使用序列创建的用户检查结果
# 注意：目前未使用
function check_sequence_users_result() {
    echo -e ""
    echo -e "\033[33m==================[12]计算节点批量创建用户检查============================\033[0m"
    return_msg=$(check_users_by_sequence)
    if [ -z "${return_msg}" ]; then
        echo -e "\033[33m==\033[0m\033[32m  计算节点批量创建用户检查正常                         [ √ ]\033[0m          \033[33m==\033[0m"
    else
        echo -e "\033[33m==\033[0m\033[31m  计算节点批量创建用户检查异常,异常用户如下:           [ X ]\033[0m          \033[33m==\033[0m"
        echo -e "${return_msg}"
    fi
    echo -e "\033[33m==================[12]计算节点批量创建用户检查============================\033[0m"
}

# 检查业务用户创建是否正常是否完整
# 用户使用的是users.json文件创建，依赖JQ组件
function check_users_by_json() {
    # users.json配置文件是否存在
    local ret_user_json_code=0
    # users.json配置文件存在为空的配置项
    local ret_json_content_code=""
    if [ "$(is_file_exist ${users_json_file})" == "1" ]; then
        ret_user_json_code=1
    else
        hpc_users=$(cat "${users_json_file}" | jq -r '.business_users | .[]')
        if [ -n "${hpc_users}" ]; then
            user_name=($(echo "${hpc_users}" | jq -r '.user_name'))
            user_id=($(echo "${hpc_users}" | jq -r '.user_id'))
            group_name=($(echo "${hpc_users}" | jq -r '.group_name'))
            group_id=($(echo "${hpc_users}" | jq -r '.group_id'))
            for ((i = 0; i < ${#user_name[@]}; i++)); do
                 if [ -z "${user_name[i]}" ] || [ -z "${user_id[i]}" ] || [ -z "${group_name[i]}" ] || [ -z "${group_id[i]}" ]; then
                    if [ -z "${ret_json_content_code}" ]; then
                        ret_json_content_code[0]=$(cat "${users_json_file}" | jq -r '.business_users | .'[i])
                    else
                        local array_length=${#ret_json_content_code[@]}
                        ret_json_content_code[${array_length}+1]=$(cat "${users_json_file}" | jq -r '.business_users | .'[${i}])
                    fi
                 else
                    # 检查用户组是否存在，如果不存在创建
                    # 如果存在检查用户组以及用户组id是否正确
                    egrep "^${group_name[i]}" /etc/group >&/dev/null
                    if [ $? -ne 0 ]; then
                        if [ -z "${ret_json_content_code}" ]; then
                            ret_json_content_code[0]=$(cat "${users_json_file}" | jq -r '.business_users | .'[${i}])
                        else
                            local array_length=${#ret_json_content_code[@]}
                            ret_json_content_code[${array_length}+1]=$(cat "${users_json_file}" | jq -r '.business_users | .'[${i}])
                        fi
                    else
                        # 检查并创建用户
                        egrep "^${user_name[i]}" /etc/passwd >&/dev/null
                        if [ $? -ne 0 ]; then
                            if [ -z "${ret_json_content_code}" ]; then
                                ret_json_content_code[0]=$(cat "${users_json_file}" | jq -r '.business_users | .'[${i}])
                            else
                                local array_length=${#ret_json_content_code[@]}
                                ret_json_content_code[${array_length}+1]=$(cat "${users_json_file}" | jq -r '.business_users | .'[${i}])
                            fi
                        fi  
                    fi
                 fi
            done
        fi  
    fi
    echo ${ret_json_content_code[@]}
}

function check_json_users_result() {
    echo -e ""
    echo -e "\033[33m==================[12]计算节点批量创建用户检查============================\033[0m"
    return_msg=$(check_users_by_json)
    if [ "$(is_file_exist ${users_json_file})" == "0" ]; then
        echo -e "\033[33m==\033[0m\033[32m  配置文件[users.json]存在                             [ √ ]\033[0m          \033[33m==\033[0m"
        if [ -z "${return_msg}" ]; then
            echo -e "\033[33m==\033[0m\033[32m  计算节点批量创建用户检查正常                         [ √ ]\033[0m          \033[33m==\033[0m"
        else
            echo -e "\033[33m==\033[0m\033[31m  计算节点批量创建用户检查异常,异常用户如下:           [ X ]\033[0m          \033[33m==\033[0m"
            echo -e "${return_msg}" | jq -r '.'
        fi
    else
        echo -e "\033[33m==\033[0m\033[31m  配置文件[users.json]不存在                           [ X ]\033[0m          \033[33m==\033[0m"
    fi
    echo -e "\033[33m==================[12]计算节点批量创建用户检查============================\033[0m"
}

# 根据不同操作系统安装不同的JQ
function install_jq() {
    # 安装麒麟操作系统软件以及依赖包
    if [ -n "$(cat /etc/system-release | grep -i -w Kylin)" ]; then
        cd ${sourcecode_dir}/jq
        if [ -z "$(find_file_by_path ${sourcecode_dir}/jq jq-1.5 rpm)" ]; then
            log_error "Jq dependency package doesn't exist, couldn't install jq." false
            return 1
        else
            yum localinstall -y *.rpm >> ${operation_log_path}/access_all.log 2>&1
            return 0
        fi
    fi
    # 安装欧拉操作系统jq软件以及依赖包
    if [ -n "$(cat /etc/system-release | grep -i -w openEuler)" ]; then
        yum install -y jq >> ${operation_log_path}/access_all.log 2>&1
        return 0
    fi
    # 安装CentOS操作系统jq软件以及依赖包
    if [ -n "$(cat /etc/system-release | grep "CentOS Linux release 7.6.1810")" ]; then
        cd ${sourcecode_dir}/jq
        if [ -z "$(find_file_by_path ${sourcecode_dir}/jq jq-1.5 rpm)" ]; then
            log_error "Jq dependency package doesn't exist, couldn't install jq." false
            return 1
        else
            yum localinstall -y *.rpm >> ${operation_log_path}/access_all.log 2>&1
            return 0
        fi
    fi
    if [ -n "$(cat /etc/system-release | grep "CentOS Linux release 8.2.2004")" ]; then
        if [ -n "$(yum list | grep jq)" ]; then
            yum install -y jq >> ${operation_log_path}/access_all.log 2>&1
        else
            log_error "Jq dependency package doesn't exist, couldn't install jq." false
            return 1
        fi
    fi
}

# 创建用户
function create_users_by_json() {
    # users.json配置文件是否存在
    local ret_user_json_code=0
    # 检查文件是否存在
    if [ "$(is_file_exist ${users_json_file})" == "0" ]; then
        # 获取business_users节点的用户信息 | .user_name,.user_id' sed -n "N;s/\n/ /p
        hpc_users=$(cat "${users_json_file}" | jq -r '.business_users | .[]')
        if [ -n "${hpc_users}" ]; then
            user_name=($(echo "${hpc_users}" | jq -r '.user_name'))
            user_id=($(echo "${hpc_users}" | jq -r '.user_id'))
            group_name=($(echo "${hpc_users}" | jq -r '.group_name'))
            group_id=($(echo "${hpc_users}" | jq -r '.group_id'))
    
            for ((i = 0; i < ${#user_name[@]}; i++)); do
                log_info ${user_name[i]} false
                # 检查用户组是否存在，如果不存在创建
                # 如果存在检查用户组以及用户组id是否正确
                egrep "^${group_name[i]}" /etc/group >&/dev/null
                if [ $? -ne 0 ]; then
                    # 新增用户组
                    groupadd ${group_name[i]} -g ${group_id[i]}
                else
                    gid=$(egrep "^${group_name[i]}" /etc/group | gawk -F: '{print $3}') >&/dev/null
                    log_info "\${gid} = ${gid}" false
                    if [ "${gid}" != "${group_id[i]}" ]; then
                        groupdel ${group_name[i]}
                        groupadd ${group_name[i]} -g ${group_id[i]}
                    fi
                fi
                # 检查并创建用户
                egrep "^${user_name[i]}" /etc/passwd >&/dev/null
                if [ $? -ne 0 ]; then
                    useradd -u ${user_id[i]} -g ${group_id[i]} -d /home/${user_name[i]} ${user_name[i]}
                    echo ${user_password} | sudo passwd --stdin ${user_name[i]} >&/dev/null
                else
                    # 强制将某个用户直接设置到对应的组
                    usermod -G ${group_name[i]} ${user_name[i]}
                fi
            done
        else
            log_error "Jq parsing ${users_json_file} error, checking configuration is correct." false
            ret_user_json_code=2
        fi
    else
        log_error "${users_json_file} file doesn't exist." false
        ret_user_json_code=1
    fi   
}

function create_users_result() {
    echo -e ""
    echo -e "\033[33m==================[13]计算节点批量创建用户开始============================\033[0m"
    # 调用创建用户方法
    create_users_by_json
    # create_users_by_sequence
    if [ "$?" == "3" ]; then
         echo -e "\033[33m==\033[0m\033[31m  解析[users.json]文件jq的软件不存在                   [ X ]\033[0m          \033[33m==\033[0m"
    else
        # 检查用户创建
        local return_msg=$(check_users_by_json)
        if [ "$(is_file_exist ${users_json_file})" == "0" ]; then
            echo -e "\033[33m==\033[0m\033[32m  配置文件[users.json]存在                             [ √ ]\033[0m          \033[33m==\033[0m"
            if [ -z "${return_msg}" ]; then
                echo -e "\033[33m==\033[0m\033[32m  计算节点批量创建用户创建成功                         [ √ ]\033[0m          \033[33m==\033[0m"
            else
                echo -e "\033[33m==\033[0m\033[31m  计算节点批量创建用户创建异常,异常用户如下:           [ X ]\033[0m          \033[33m==\033[0m"
                echo -e "${return_msg}" | jq -r '.'
            fi
        else
            echo -e "\033[33m==\033[0m\033[31m  配置文件[users.json]不存在                           [ X ]\033[0m          \033[33m==\033[0m"
        fi  
    fi
    echo -e "\033[33m==================[13]计算节点批量创建用户结束============================\033[0m"
}

# 脚本执行合法性检查
function required_check() {
    if [ $(is_file_exist ${users_json_file}) == "1" ]; then
        log_error "[${users_json_file}] file doesn't exist, please check." true
        return 1
    fi
    # 检查jq依赖工具是否安装
    if [ "$(rpm -qa jq)" == "" ]; then
        install_jq
        if [ "$?" == "1" ]; then
            log_error "Jq dependency package doesn't exist, please check."
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
manual_script_action ${is_manual_script} ${is_open_debug} required_check check_json_users_result create_users_result ${4}
