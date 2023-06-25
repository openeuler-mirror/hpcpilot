#
# Copyright (c) Huawei Technologies Co., Ltd. 2022-2022. All rights reserved.
#

#!/usr/bin/env bash
######################################################################
# 脚本描述：安装Mellanox网卡驱动自动化脚本                                  #
# 注意事项：1=IB网络 2=RoCE网络 3=TCP以太网络,如未填写默认值为3               #
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

# 配置使用所需网络标识（1=IB网络 2=RoCE网络 3=TCP以太网络）,如未填写默认值为3
network_type=$(get_ini_value basic_conf basic_network_type 3)
# 配置使用网络VLAN的标识VID，如未填写默认值为701
vlan_vid=$(get_ini_value basic_conf basic_vlan_vid 701)
# 软件安装路径
mellanox_install_path=/usr/local/mellanox
# mellanox网卡驱动文件名
mellanox_driver_name=""
# 全局返回值变量
return_message=""
# mellanox高速网卡计算IP地址
mlx_computer_ip=""
# mellanox高速网卡存储IP地址
mlx_storage_ip=""

# 检查是否安装mellanox驱动
function check_mellanox() {
    # 2代表当前是虚拟机无需安装 1代表mellanox驱动未安装 0代表已经安装；
    local ret_install_code="0"
    # 1代表mellanox网卡未启动 0代表已经启动；
    local ret_start_code="0"
    # 检查判断是否是物理机
    if [ "$(is_physical_machine)" == "1" ]; then
        log_info "Virtual machine, mellanox driver does not need to be installed." false
        ret_install_code="2"
    else
        # 物理机进行安装配置mellanox网卡驱动
        # 1. 检查是否安装mellanox网卡驱动
        if [ "$(is_command_exist "ofed_info -n")" == "0" ] || [ -z "$(ofed_info -n)" ]; then
            log_info "Current machine is not installed mellanox driver." false
            ret_install_code="1"
        else
            # TODO 20230202_网卡配置【mlxconfig -d /dev/mst/mt4125_pciconf0 -y s PF_LOG_BAR_SIZE=8】检查待讨论后优化
            # 2. 检查mellanox网卡是否启动
            # 注意: 配置完成后需要重启才可以使用ibdev2netdev命令
            if [[ $(ibdev2netdev) =~ "Up" ]]; then
                log_info "Mellanox has started." false
                ret_start_code="0"
            else
                log_info "Mellanox has not started." false
                ret_start_code="1"
            fi
        fi
    fi
    local ret_info=(${ret_install_code} ${ret_start_code})
    echo ${ret_info[@]}
}

# 检查是否安装mellanox驱动结果打印输出
function check_mellanox_result() {
    echo -e ""
    echo -e "\033[33m==================[8]计算节点Mellanox网卡驱动安装检查结果=================\033[0m"
    if [ "${network_type}" == "3" ]; then
        echo -e "\033[33m==\033[0m\033[32m  当前计算节点网络类型配置为TCP无需安装Mellanox网卡驱动[ √ ]\033[0m          \033[33m==\033[0m"
    else
        local return_msg=($(check_mellanox))
        if [ "${return_msg[0]}" == "2" ]; then
            echo -e "\033[33m==\033[0m\033[32m  当前计算节点为虚拟机无需安装Mellanox网卡驱动         [ √ ]\033[0m          \033[33m==\033[0m"
        elif [ "${return_msg[0]}" == "1" ]; then
            echo -e "\033[33m==\033[0m\033[31m  当前计算节点未安装Mellanox网卡驱动                   [ X ]\033[0m          \033[33m==\033[0m"
        else
            if [ "${return_msg[1]}" == "0" ]; then
                echo -e "\033[33m==\033[0m\033[32m  当前计算节点Mellanox网卡驱动已安装且已启动           [ √ ]\033[0m          \033[33m==\033[0m"
            else
                echo -e "\033[33m==\033[0m\033[31m  Mellanox网卡驱动已安装未启动（可能未插网线）         [ X ]\033[0m          \033[33m==\033[0m"
            fi
        fi 
    fi
    echo -e "\033[33m==================[8]计算节点Mellanox网卡驱动安装检查结果=================\033[0m"
}

# 根据不同操作系统安装不同依赖包
function install_mellanox_dependency_libs() {
    # 安装麒麟操作系统mellanox驱动依赖包
    if [ -n "$(cat /etc/system-release | grep -i -w Kylin)" ]; then
        yum install -y lsof
        cd ${sourcecode_dir}
        local tcsh_rpm=$(find_file_by_path ${sourcecode_dir}/ tcsh rpm)
        if [ -z "${tcsh_rpm}" ]; then
            log_error "Tcsh dependency package doesn't exist, couldn't install mellanox driver." false
        else
            yum install -y ${tcsh_rpm}
        fi
    fi
    # 安装欧拉操作系统mellanox驱动依赖包
    if [ -n "$(cat /etc/system-release | grep -i -w openEuler)" ]; then
        yum install -y tcsh pciutils-devel fuse-devel lsof
    fi
    # 安装CentOS V_7.6操作系统mellanox驱动依赖包
    if [ -n "$(cat /etc/system-release | grep "CentOS Linux release 7.6.1810")" ]; then
        yum install -y tcl tk pciutils lsof tcsh
    fi
    # 安装CentOS V_8.2操作系统mellanox驱动依赖包
    if [ -n "$(cat /etc/system-release | grep "CentOS Linux release 8.2.2004")" ]; then
        yum install -y gcc-gfortran python36 kernel-modules-extra tcl tk tcsh
    fi
}

# 切换网卡信息并配置PF_LOG_BAR_SIZE参数值
# 参数${1}=1时为IB模式，参数${1}=2时为RoCE模式
function switch_network() {
    # TODO 20230410_目前没有多网卡设备因此未进行多网卡测试
    local link_type_name="IB(1)"
    if [ "${1}" == "1" ]; then
        link_type_name="ETH(2)"
    fi
    # 获取设备名称(支持适配多张网卡)
    local devices=($(mlxconfig q | grep 'Device:' | awk '{print $2}'))
    for device in ${devices}; do
        if [ "$(mlxconfig -d ${device} q | grep LINK_TYPE | awk '{print $2}')" == "${link_type_name}" ]; then
            # 2. 切换网卡模式为IB模式
            mlxconfig -y -d ${device} s LINK_TYPE_P1=${1}
        fi
    done
    # 如果架构是鲲鹏则需修改PF_LOG_BAR_SIZE参数值
    if [ "$(uname -m)" == "aarch64" ]; then
        for device in ${devices}; do
            # 需要加判断
            mlxconfig -d ${device} -y s PF_LOG_BAR_SIZE=8
        done
    fi
}

# 配置IB网络
function config_ib_network() {
    # 配置网卡IP信息（ipoid）
    local net_name=$(ibdev2netdev | grep mlx | awk '{print $5}')
    # 配置ib的IP
    local config_content="DEVICE=${net_name}\nBOOTPROTO=static\nNM_CONTROLLED=no\nONBOOT=yes\nTYPE=InfiniBand\nIPADDR=${mlx_computer_ip}\nNETMAST=255.255.255.0"
    # 以覆盖的方式写入配置文件中
    echo -ne "${config_content}" > /etc/sysconfig/network-scripts/ifcfg-${net_name}
    # 重启IB网卡
    ifdown ${net_name}
    ifup ${net_name}
    # 切换网络模式为IB模式
    switch_network 1
    # 启动子网管理器SM，并设置开机自启动。HPC集群选择在管理节点启动opensm服务即可。
    if [ -n "$(echo "$(get_current_host_ip)" | grep "${om_machine_ip}")" ]; then
        /etc/init.d/opensmd restart
        systemctl enable opensm 
    fi
}

# 配置RoCE网络
function config_RoCE_network() {
    # 配置网卡IP信息
    local net_name=$(ibdev2netdev | grep mlx | awk '{print $5}')
    local vlan_name=vlan.${vlan_vid}
    local vlan_name0=${vlan_name}:0
    local net_mask=255.255.255.0
    # 配置RoCE的IP
    local net_cfg_content="DEVICE=${net_name}\nBOOTPROTO=none\nONBOOT=yes\nSTARTMODE=onboot\nDEFROUTE=no\nNM_CONTROLLED=no"
    # 以覆盖的方式写入配置文件中
    echo -ne "${net_cfg_content}" > /etc/sysconfig/network-scripts/ifcfg-${net_name}
    
    local vlan_cfg_content="DEVICE=${vlan_name}\nIPADDR=${mlx_computer_ip}\nNETMASK=${net_mask}\nNETWORKING=yes\nGATEWAY=${mlx_computer_ip%.*}.1\nDEFROUTE=no\nIPV6_AUTOCONF=no\nBOOTPROTO=static\nPHYSDEV=${net_name}\nONBOOT=yes\nUSERCTL=no\nVLAN=yes\nVID=${vlan_vid}\nNM_CONTROLLED=no"
    echo -ne "${vlan_cfg_content}" > /etc/sysconfig/network-scripts/ifcfg-${vlan_name}
    
    local vlan0_cfg_content="DEVICE=${vlan_name0}\nIPADDR=${mlx_storage_ip}\nNETMASK=${net_mask}\nDEFROUTE=no\nNO_ALIASROUTING=yes\nIPV6_AUTOCONF=no\nBOOTPROTO=static\nPHYSDEV=${net_name}\nONBOOT=yes\nUSERCTL=no\nVLAN=yes\nVID=${vlan_vid}\nNM_CONTROLLED=no"
    echo -ne "${vlan0_cfg_content}" > /etc/sysconfig/network-scripts/ifcfg-${vlan_name0}
    # 重启RoCE网卡配置
    systemctl restart NetworkManager
    # 优化Mellanox网卡驱动
    if [ ! -f "/etc/init.d/cx.sh" ]; then
        local share_dir=$(get_ini_value basic_conf basic_shared_directory /share)
        # 复制cx.sh文件到/etc/init.d/文件夹中
        cp -f ${base_directory}/basic_script/cx.sh /etc/init.d/
        # 添加可执行权限
        chmod +x /etc/init.d/cx.sh
        # 为cx.sh添加开机自启动
        echo -ne "sh /etc/init.d/cx.sh" >> /etc/rc.local
        # 为/etc/rc.local文件添加可执行权限
        chmod +x /etc/rc.local
    fi
    # 执行cx.sh进行Mellanox网卡优化
    sh /etc/init.d/cx.sh
    # 切换网络模式为RoCE模式
    switch_network 2
}

# 配置TCP以太网络
function config_tcp_network() {
    # 无需安装和配置mellanox网卡驱动
    log_info "Current network_type is tcp, do not need to install mellanox driver." false
    check_mellanox_result
}

# 安装并配置优化mellanox网卡驱动
function install_and_config_mellanox() {
    if [ "${network_type}" == "3" ]; then
        config_tcp_network
        return
    fi
    # 判断network_type值合法性
    if [ "${network_type}" != "1" ] && [ "${network_type}" != "2" ]; then
        log_error "Unknown network type value [${network_type}]." false
        return
    fi
    # 安装mellanox网卡驱动
    mellanox_driver_name=$(find_file_by_path ${sourcecode_dir}/ MLNX_OFED_LINUX tgz)
    if [ "${mellanox_driver_name}" != "" ]; then
        # 创建解压的目标目录
        if [ ! -d "${mellanox_install_path}/" ]; then
            mkdir -m 755 -p ${mellanox_install_path}/
        fi
        # 根据不同操作系统安装不同依赖包
        install_mellanox_dependency_libs
        cd ${sourcecode_dir}
        tar -zxvf ${mellanox_driver_name} -C ${mellanox_install_path}/
        # 去掉后缀名切换到解压后的目录
        cd ${mellanox_install_path}/$(basename ${mellanox_driver_name} .tgz)
        # 执行安装 
        # 在调用mlnxofedinstall安装过程中有手动输入的交互,使用--force 屏蔽输入交互
        ./mlnxofedinstall --force
        # 从内存中移除已经存在的模块，否则可能导致/etc/init.d/openibd restart 重启失败
        if [ -n "$(lsmod | grep -i -w hns_roce_hw_v2)" ]; then
            rmmod hns_roce_hw_v2
        fi
        if [ -n "$(lsmod | grep -i -w hns_roce)" ]; then
            rmmod hns_roce
        fi
        # 设置下一次启动时更新驱动
        dracut -f
        # 安装完成后执行以下命令加载驱动
        /etc/init.d/openibd restart
        log_info "Mellanox driver version is $(ofed_info -n)." false
        # 配置网卡参数并启动
        mst start
        ############### mellanox网卡驱动配置优化 ###############
        if [ "${network_type}" == "1" ]; then
            config_ib_network
        elif [ "${network_type}" == "2" ]; then
            config_RoCE_network
        else
            log_error "Unknown network type value [${network_type}]." false
        fi
        # TODO 20230203_配置完成后需要重新启动
        # reboot
        log_info "Mellanox driver installation and configuration are complete." false
    else
        # 未找到mellanox驱动文件
        log_error "Mellanox driver file is not found, could not install." false
    fi
}

# 安装mellanox驱动
function install_mellanox_result() {
    install_and_config_mellanox >> ${operation_log_path}/access_all.log 2>&1
    check_mellanox_result
}

# 脚本执行合法性检查
function required_check() {
    if [ "$(is_physical_machine)" == "0" ]; then
        if [ "${network_type}" == "3" ]; then
            return 0
        fi
        if [ "$(find_file_by_path ${sourcecode_dir}/ MLNX_OFED_LINUX tgz)" == "" ]; then
            log_error "[${sourcecode_dir}/] directory mellanox driver file doesn't exist, please check." true
            return 1
        fi
        if [ -n "$(cat /etc/system-release | grep -i -w Kylin)" ] && [ -z "$(find_file_by_path ${sourcecode_dir}/ tcsh rpm)" ]; then
            log_error "[${sourcecode_dir}/] tcsh dependency package doesn't exist, please check." true
            return 1
        fi
        if [ -n "$(cat /etc/system-release | grep -i -w CentOS)" ]; then
            if [ -z "$(yum list | grep tcl)" ]; then
                log_error "tcl dependency package doesn't exist from yum source, please check." true
                return 1
            fi
            if [ -z "$(yum list | grep tk)" ]; then
                log_error "tk dependency package doesn't exist from yum source, please check." true
                return 1
            fi
            if [ -z "$(yum list | grep pciutils)" ]; then
                log_error "pciutils dependency package doesn't exist from yum source, please check." true
                return 1
            fi
            if [ -z "$(yum list | grep lsof)" ]; then
                log_error "lsof dependency package doesn't exist from yum source, please check." true
                return 1
            fi
        fi
        # 判断network_type值合法性
        if [ -z "$(echo "(1 2 3)" | grep -w "${network_type}")" ]; then
            log_error "Unknown network type value [${network_type}], please check." true
            return 1
        fi
        if [ $(is_file_exist ${hostname_file}) == "1" ]; then
            log_error "[${hostname_file}] file doesn't exist, please check." true
            return 1
        fi
        # 检查是否配置了Mellanox网卡高速IP
        if [ "${network_type}" == "1" ]; then
            # tail -n +2 从第二行开始读取数据，第一行为标题行
            for line in $(cat ${hostname_file} | tail -n +2); do
                # 检查判断字符串长度是否为0
                if [ -n "${line}" ]; then
                    local host_ip=$(echo ${line} | awk -F "," '{print $1}' | sed -e 's/\r//g')
                    if [ -n "$(echo "$(get_current_host_ip)" | grep "${host_ip}")" ]; then
                        mlx_computer_ip=$(echo ${line} | awk -F "," '{print $5}' | sed -e 's/\r//g')
                        if [ -z "${mlx_computer_ip}" ]; then
                            log_error "Ip address of the high-speed NIC is empty, please check." true
                            return 1
                        fi
                        # IP地址合法性检查
                        if [ "$(valid_ip_address ${mlx_computer_ip})" == "1" ]; then
                            log_error "Ip address [${mlx_computer_ip}] of the high-speed NIC is invalid, please check." true
                            return 1
                        fi
                    fi
                fi
            done
            return 0
        fi
        if [ "${network_type}" == "2" ]; then
            # tail -n +2 从第二行开始读取数据，第一行为标题行
            for line in $(cat ${hostname_file} | tail -n +2); do
                # 检查判断字符串长度是否为0
                if [ -n "${line}" ]; then
                    local host_ip=$(echo ${line} | awk -F "," '{print $1}' | sed -e 's/\r//g')
                    if [ -n "$(echo "$(get_current_host_ip)" | grep "${host_ip}")" ]; then
                        mlx_computer_ip=$(echo ${line} | awk -F "," '{print $5}' | sed -e 's/\r//g')
                        mlx_storage_ip=$(echo ${line} | awk -F "," '{print $6}' | sed -e 's/\r//g')
                        if [ -z "${mlx_computer_ip}" ] || [ -z "${mlx_storage_ip}" ]; then
                            log_error "Ip address of the high-speed NIC is empty, please check." true
                            return 1
                        fi
                        # IP地址合法性检查
                        if [ "$(valid_ip_address ${mlx_computer_ip})" == "1" ] || [ "$(valid_ip_address ${mlx_storage_ip})" == "1" ]; then
                            log_error "Ip address [${mlx_computer_ip} ${mlx_storage_ip}] of the high-speed NIC is invalid, please check." true
                            return 1
                        fi
                    fi
                fi
            done
            return 0
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
manual_script_action ${is_manual_script} ${is_open_debug} required_check check_mellanox_result install_and_config_mellanox ${4}
