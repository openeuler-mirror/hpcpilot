#
# Copyright (c) Huawei Technologies Co., Ltd. 2023-2023. All rights reserved.
#

#!/usr/bin/env bash
######################################################################
# 脚本描述：一键式创建DonauKit所需目录                               #
# 注意事项：无                                                       #
######################################################################
# 引用公共方法
current_dir=$(cd $(dirname "$0"); pwd)
. "${current_dir}"/../common.sh

# 获取共享路径
share_hpc_dir=${1}

# DonauKit 所需路径列表（全部路径，统一创建）
dirs=("donau" "license" "data" "dataupload" "jobdata" "portal_data" "scheduler_db" "portal_db" "backup" "scheduler_agent" "mpi" "storage")

# 目录关键属主列表
users=("ccp_master" "ccs_master")

# 创建路径并赋予权限
function add_dir(){
echo -e ""
echo -e "\033[33m======================开始创建DonauKit共享目录============================\033[0m"
    for dir in "${dirs[@]}"
    do
        path="${1}/${dir}"
        if [ ! -d "${path}" ];then
            mkdir -p ${path}
            if [ $? -ne 0 ];then
                printf "\033[33m%-4s\033[0m \033[32m%-53s\033[0m \033[32m%-20s\033[0m \033[33m%-2s\033[0m\n" "==" "创建目录${dir}失败" "[ X ]" "=="
                exit 1
            else
                printf "\033[33m%-4s\033[0m \033[32m%-53s\033[0m \033[32m%-20s\033[0m \033[33m%-2s\033[0m\n" "==" "创建目录${dir}成功" "[ √ ]" "=="
            fi
        else
            printf "\033[33m%-4s\033[0m \033[32m%-54s\033[0m \033[32m%-20s\033[0m \033[33m%-2s\033[0m\n" "==" "目标文件${dir}已存在" "[ √ ]" "=="
        fi

        if [ "${dir}" = "storage" ];then
            chmod 755 "${1}/${dir}"
            chown ccp_master: "${1}/${dir}"
        elif [ "${dir}" = "donau" ];then
            chmod 700 "${1}/${dir}"
        elif [ "${dir}" = "license" ];then
            chmod 770 "${1}/${dir}"
            chown ccs_master:ccs_master "${1}/${dir}"
        elif [ $dir = "data" ];then
            chmod 750 "${1}/${dir}"
            chown ccs_master:ccs_master "${1}/${dir}"
        elif [ $dir = "dataupload" ];then
            chmod 700 "${1}/${dir}"
            chown ccp_master: "${1}/${dir}"
        else
            chmod 755 "${1}/${dir}"
        fi
    done
echo -e "\033[33m======================DonauKit共享目录创建完成============================\033[0m"
}

############### 主函数入口 ###############
if [ ! -e ${share_hpc_dir} ]; then
    echo -e "\033[33m==\033[0m\033[31m  共享目录不存在.                           [ X ]\033[0m          \033[33m==\033[0m"
    exit 1
fi

# 校验当前执行用户是否是root
currentuser=`whoami`
check_user "${currentuser}"
ret=$?
if [ 0 != ${ret} ]; then
    echo -e "\033[33m==\033[0m\033[31m  脚本执行用户不是root.                           [ X ]\033[0m          \033[33m==\033[0m"
    exit 1
fi

# 校验ccp_master、ccs_master用户是否存在
for user in "${users[@]}"
do
    check_user "${user}"
    ret=$?
    if [ 0 != ${ret} ]; then
        echo -e "\033[33m==\033[0m\033[31m  User ${user} does not exist.                            [ X ]\033[0m          \033[33m==\033[0m"
        exit 1
    fi
done

# 在共享目录下创建donau文件夹，作为DonauKit个服务目录入口
share_donau_dir=${share_hpc_dir}/donau

# 执行创建目录脚本
add_dir ${share_donau_dir}
