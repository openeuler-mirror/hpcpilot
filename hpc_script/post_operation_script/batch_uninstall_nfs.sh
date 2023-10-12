#
# Copyright (c) Huawei Technologies Co., Ltd. 2023-2023. All rights reserved.
#

#!/usr/bin/env bash
######################################################################
# 脚本描述：一键式卸载临时nfs目录                                    #
# 注意事项：无                                                       #
######################################################################

# 引用公共方法
current_dir=$(cd $(dirname "$0"); pwd)
. "${current_dir}"/../common.sh

# 临时nfs客户端目录
share_dir=$(get_ini_value basic_conf basic_shared_directory /share)
if [ "" = "${share_dir}" ]; then
    echo "The param share_dir is empty, please check setting.ini."
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

# 进行二次确认，是否删除所有临时nfs目录
read_input_yes_or_no "Do you want to remove the temporary nfs directory of all nodes ?"
if [ $? == 1 ]; then
    echo "Program continue..."
else
    echo "Program exit."
    exit 0
fi

# 检查是否安装了ansible
rpm -qa | grep ansible > /dev/null 2>&1
if [ $? -ne 0 ]; then
    echo "Ansible is not installed or fails to be installed."
    exit 1
fi

echo -e "\033[33m======================开始卸载临时NFS共享目录=============================\033[0m"
# 所有节点卸载临时nfs目录
ansible all -m shell -a "${current_dir}/cac_uninstall_temp_nfs.sh ${share_dir}" -t ${ansible_log_path}

# 检查nfs目录是否卸载
ansible all -m shell -a "${current_dir}/cac_check_temp_nfs.sh ${share_dir}" -t ${ansible_log_path}
echo -e "\033[33m======================临时NFS目录卸载完成=================================\033[0m"
