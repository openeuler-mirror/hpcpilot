#
# Copyright (c) Huawei Technologies Co., Ltd. 2023-2023. All rights reserved.
#

#!/usr/bin/env bash
######################################################################
# 脚本描述：一键式配置autofs                                         #
# 注意事项：无                                                       #
######################################################################

# 引用公共方法
current_dir=$(cd $(dirname "$0"); pwd)
. "${current_dir}"/../common.sh

# 是否启用autofs
enable_autofs=$(get_ini_value post_operation_conf enable_autofs false)
if [ "false" = ${enable_autofs} ]; then
    echo "Autofs self-mounting mount dpc is not enabled."
    exit 0
fi

# 获取dpc_file_system_name
dfc_file_system_name=$(get_ini_value post_operation_conf dfc_file_system_name)
if [ "" = "${dfc_file_system_name}" ]; then
    echo "The param dpf_file_system_name is empty, please check setting.ini."
    exit 1
fi
dfc_file_system_name_list=(`echo "${dfc_file_system_name}" | tr ',' ' '`)

# 获取local_path
local_path=$(get_ini_value post_operation_conf local_path)
if [ "" = "${local_path}" ]; then
    echo "The param local_path is empty, please check setting.ini."
    exit 1
fi
local_path_list=(`echo "${local_path}" | tr ',' ' '`)

# 判断dpc_file_system_name与local_path个数是否一致
if [ ${#dfc_file_system_name_list[@]} -ne ${#local_path_list[@]} ]; then
    echo "The number of parameters dfc_file_system_name and local_path is inconsistent."
    exit 1
fi

# 校验当前执行用户是否是root
currentuser=`whoami`
check_user "${currentuser}"
ret=$?
if [ 0 != ${ret} ]; then
    echo -e "The current execution user is not root, please execute the script as root."
    exit 1
fi

# 检查是否安装了ansible
rpm -qa | grep ansible > /dev/null 2>&1
if [ $? -ne 0 ]; then
    echo "Ansible is not installed or fails to be installed."
    exit 1
fi

echo -e "\033[33m======================开始配置autofs服务==================================\033[0m"

# 所有节点配置autofs
ansible all -m shell -a "${current_dir}/cac_autofs_configure.sh ${dfc_file_system_name_list} ${local_path_list}" -t ${ansible_log_path}

echo -e "\033[33m======================autofs服务配置完成==================================\033[0m"