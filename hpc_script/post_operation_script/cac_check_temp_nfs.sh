#
# Copyright (c) Huawei Technologies Co., Ltd. 2023-2023. All rights reserved.
#

#!/usr/bin/env bash
######################################################################
# 脚本描述：卸载临时nfs目录                                          #
# 注意事项：无                                                       #
######################################################################

share_dir=$1

if [ "" = "${share_dir}" ]; then
    echo "The param share_dir is empty."
    exit 1
fi

# 获取节点名称
host_name=$(hostname)

# 校验目录是否解挂
mount | grep "${share_dir}" | grep nfs > /dev/null 2>&1
if [ $? -eq 0 ]; then
    printf "\033[33m%-4s\033[0m \033[32m%-53s\033[0m \033[32m%-20s\033[0m \033[33m%-2s\033[0m\n" "==" "${host_name}节点的${share_dir}目录解挂失败。" "[ X ]" "=="
else
    printf "\033[33m%-4s\033[0m \033[32m%-53s\033[0m \033[32m%-20s\033[0m \033[33m%-2s\033[0m\n" "==" "${host_name}节点的${share_dir}目录解挂成功。" "[ √ ]" "=="
fi

