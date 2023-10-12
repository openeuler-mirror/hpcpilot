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

# 校验目录为nfs协议挂载
mount | grep "${share_dir}" | grep nfs > /dev/null 2>&1
if [ $? -ne 0 ]; then
    echo "The target_dir is not mounted by nfs, please check whether the basic_shared_directory is filled in correctly."
    exit 1
fi

# 卸载nsf目录
umount -l "${share_dir}"