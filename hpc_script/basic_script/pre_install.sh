#
# Copyright (c) Huawei Technologies Co., Ltd. 2022-2022. All rights reserved.
#
#!/usr/bin/env bash
# 提供解决安装过程中ANSIBLE无法调用方法的问题

# 引用公共函数文件开始
if [ "${1}" == "opt" ]; then
    # 定义脚本文件、配置文件存放目录
    base_directory=/${1}/hpcpilot/hpc_script
else
    # 定义脚本文件、配置文件存放目录
    base_directory=/${1}/software/tools/hpc_script
fi
source ${base_directory}/common.sh ${1}
# 引用公共函数文件结束

function main() {
    # 检查并安装基础命令
    log_info "Checking and installing basic commands." false
    basic_commands_install
}

main
