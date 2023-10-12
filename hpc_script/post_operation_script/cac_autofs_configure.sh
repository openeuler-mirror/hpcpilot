#
# Copyright (c) Huawei Technologies Co., Ltd. 2023-2023. All rights reserved.
#

#!/usr/bin/env bash
######################################################################
# 脚本描述：配置autofs自动挂载dpc                                    #
# 注意事项：无                                                       #
######################################################################

# 引用公共方法
current_dir=$(cd $(dirname "$0"); pwd)
. "${current_dir}"/../common.sh

dfc_file_system_name_list=$1
local_path_list=$2

if [ "" = "${dfc_file_system_name_list}" ]; then
    echo "The param dfc_file_system_name is empty."
    exit 1
fi

if [ "" = "${local_path_list}" ]; then
    echo "The param local_path is empty."
    exit 1
fi

# 开始配置autofs
yum -y install autofs > /dev/null 2>&1
echo "/- /etc/auto.mnt" > /etc/auto.master
systemctl enable autofs.service > /dev/null 2>&1
touch /etc/auto.mnt

# 建立本地目录与共享目录的映射关系
length=${#dfc_file_system_name_list[@]}
for ((i=0; i<${length}; i++))
do
    mkdir -p "${local_path_list[$i]}"
    echo "${local_path_list[$i]} -fstype=dpc :${dfc_file_system_name_list[$i]}" >> /etc/auto.mnt
done

# 配置autofs取消自动卸载
sed -i "s/timeout = 300/timeout = 0/g" /etc/autofs.conf

# 重启autofs服务，使配置生效
systemctl restart autofs.service > /dev/null 2>&1
