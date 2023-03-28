#!/usr/bin/env bash
# 批量创建业务用户自动化脚本

# 引用公共函数文件开始
source /${3}/software/tools/hpc_script/common.sh ${3}
# 引用公共函数文件结束

# 软件文件所在路径
sourcecode_dir=$(get_sourcecode_dir)
# users.json文件存放路径
users_json_file=$(get_ini_value basic_conf basic_shared_directory /share)/software/tools/hpc_script/users.json
# 业务用户密码
user_password=$(get_ini_value common_global_conf common_sys_user_password 'Huawei12#$123456')

# 检查用户创建是否完整
function check_users() {
    # users.json配置文件是否存在
    ret_user_json_code=0
    # users.json配置文件存在为空的配置项
    ret_json_content_code=""
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

function check_users_result() {
    echo -e ""
    echo -e "\033[33m==================[13]计算节点批量创建用户检查============================\033[0m"
    return_msg=$(check_users)
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
    echo -e "\033[33m==================[13]计算节点批量创建用户检查============================\033[0m"
}

# 根据不同操作系统安装不同的JQ
function install_jq_libs() {
    # 安装麒麟操作系统软件以及依赖包
    if [ -n "$(cat /etc/system-release | grep -i Kylin)" ]; then
        cd ${sourcecode_dir}/jq
        local jq_rpm=$(find_file_by_path ${sourcecode_dir}/jq jq-1.5 rpm)
        if [ -z "${jq_rpm}" ]; then
            log_error "$(get_current_host_info)_jq dependency package does not exist, couldn't install jq." false
            return 1
        else
            yum localinstall -y *.rpm
            return 0
        fi
    fi
    # 安装欧拉操作系统jq软件以及依赖包
    if [ -n "$(cat /etc/system-release | grep -i openEuler)" ]; then
        yum install -y jq
        return 0
    fi
    # 安装CentOS操作系统jq软件以及依赖包
    if [ -n "$(cat /etc/system-release | grep -i CentOS)" ]; then
        cd ${sourcecode_dir}/jq
        local jq_rpm=$(find_file_by_path ${sourcecode_dir}/jq jq-1.5 rpm)
        if [ -z "${jq_rpm}" ]; then
            log_error "$(get_current_host_info)_jq dependency package does not exist, couldn't install jq." false
            return 1
        else
            yum localinstall -y *.rpm
            return 0
        fi
    fi
}

# 创建用户
function create_users() {
    # users.json配置文件是否存在
    local ret_user_json_code=0
    # 检查安装jq JSON处理服务
    if [ "$(rpm -qa jq)" == "" ]; then
        install_jq_libs
        if [ "$?" == "1" ]; then
            ret_user_json_code=3
            return 3
        fi
    fi
    
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
                    echo ${cons_user_pwd} | sudo passwd --stdin ${user_name[i]} >&/dev/null
                else
                    # 强制将某个用户直接设置到对应的组
                    usermod -G ${group_name[i]} ${user_name[i]}
                fi
            done
        else
            log_error "jq parsing ${users_json_file} error, check whether the configuration is correct." false
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
    create_users
    if [ "$?" == "3" ]; then
         echo -e "\033[33m==\033[0m\033[31m  解析[users.json]文件jq的软件不存在                   [ X ]\033[0m          \033[33m==\033[0m"
    else
        # 检查用户创建
        return_msg=$(check_users)

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
        echo -e "\033[31m [${users_json_file}] file does not exist, system exit.\033[0m"
        return 1
    fi
    # 检查jq依赖工具是否安装
    if [ "$(rpm -qa jq)" == "" ]; then
        install_jq_libs
        if [ "$?" == "1" ]; then
            echo -e "\033[31m jq dependency package does not exist, system exit.\033[0m"
            return 1
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
manual_script_action ${is_manual_script} ${is_open_debug} required_check check_users_result create_users_result
