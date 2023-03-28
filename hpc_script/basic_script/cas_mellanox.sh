#!/usr/bin/env bash
# 安装Mellanox网卡驱动自动化脚本

# 引用公共函数文件开始
source /${3}/software/tools/hpc_script/common.sh ${3}
# 引用公共函数文件结束

# mellanox网卡驱动文件所在路径
sourcecode_dir=$(get_sourcecode_dir)
# 软件安装路径
mellanox_install_path=/usr/local/mellanox
# mellanox网卡驱动文件名
mellanox_driver_name=""
# 全局返回值变量
return_message=""

# 检查是否安装mellanox驱动
function check_mellanox() {
    # 2代表当前是虚拟机无需安装 1代表mellanox驱动未安装 0代表已经安装；
    local ret_install_code="0"
    # 1代表mellanox网卡未启动 0代表已经启动；
    local ret_start_code="0"
    # 检查判断是否是物理机
    if [ "$(is_physical_machine)" == "1" ]; then
        log_info "$(get_current_host_info)_is a virtual machine, mellanox driver does not need to be installed." false
        ret_install_code="2"
    else
        # 物理机进行安装配置mellanox网卡驱动
        # 1. 检查是否安装mellanox网卡驱动
        if [ "$(is_command_exist "ofed_info -n")" == "0" ] || [ -z "$(ofed_info -n)" ]; then
            log_info "$(get_current_host_info)_is not installed mellanox driver." false
            ret_install_code="1"
        else
            # TODO 20230202_网卡配置【mlxconfig -d /dev/mst/mt4125_pciconf0 -y s PF_LOG_BAR_SIZE=8】检查待讨论后优化
            # 2. 检查mellanox网卡是否启动
            # 注意: 配置完成后需要重启才可以使用ibdev2netdev命令
            if [[ $(ibdev2netdev) =~ "Up" ]]; then
                log_info "$(get_current_host_info)_mellanox has started." false
                ret_start_code="0"
            else
                log_info "$(get_current_host_info)_mellanox has not started." false
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
    local return_msg=($(check_mellanox))
    if [ "${return_msg[0]}" == "2" ]; then
        echo -e "\033[33m==\033[0m\033[32m  当前计算节点为虚拟机无需安装Mellanox网卡驱动         [ √ ]\033[0m          \033[33m==\033[0m"
    elif [ "${return_msg[0]}" == "1" ]; then
        echo -e "\033[33m==\033[0m\033[31m  当前计算节点未安装Mellanox网卡驱动                   [ X ]\033[0m          \033[33m==\033[0m"
    else
        if [ "${return_msg[1]}" == "0" ]; then
            echo -e "\033[33m==\033[0m\033[32m  当前计算节点Mellanox网卡驱动已安装且已启动           [ √ ]\033[0m          \033[33m==\033[0m"
        else
            echo -e "\033[33m==\033[0m\033[31m  当前计算节点Mellanox网卡驱动已安装未启动             [ X ]\033[0m          \033[33m==\033[0m"
        fi
    fi
    echo -e "\033[33m==================[8]计算节点Mellanox网卡驱动安装检查结果=================\033[0m"
}

# 根据不同操作系统安装不同依赖包
function install_mellanox_dependency_libs() {
    # 安装麒麟操作系统mellanox驱动依赖包
    if [ -n "$(cat /etc/system-release | grep -i Kylin)" ]; then
        yum install -y lsof
        cd ${sourcecode_dir}
        local tcsh_rpm=$(find_file_by_path ${sourcecode_dir}/ tcsh rpm)
        if [ -z "${tcsh_rpm}" ]; then
            log_error "$(get_current_host_info)_tcsh dependency package does not exist, couldn't install mellanox driver." false
        else
            yum install -y ${tcsh_rpm}
        fi
    fi
    # 安装欧拉操作系统mellanox驱动依赖包
    if [ -n "$(cat /etc/system-release | grep -i openEuler)" ]; then
        yum install -y tcsh pciutils-devel fuse-devel lsof
    fi
    # 安装CentOS操作系统mellanox驱动依赖包
    if [ -n "$(cat /etc/system-release | grep -i CentOS)" ]; then
        yum install -y tcl tk pciutils lsof
    fi
}

# 安装mellanox驱动
function install_mellanox() {
    # 检查是否已安装
    return_message=($(check_mellanox))
    if [ "${return_message[0]}" == "1" ]; then
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
            # 设置下一次启动时更新驱动
            dracut -f
            # 安装完成后执行以下命令加载驱动
            /etc/init.d/openibd restart
            log_info "$(get_current_host_info)_mellanox driver version is $(ofed_info -n)." false
            
            # 配置网卡参数并启动
            mst start
            ############### 网卡配置 ###############
            # 1.获取设备名称
            local devices=($(mlxconfig q|grep 'Device:'|awk '{print $2}'))
            # 2.配置网卡信息
            for device in ${devices}; do
                mlxconfig -d ${device} -y s PF_LOG_BAR_SIZE=8
            done
            # TODO 20230203_配置完成后需要重新启动
            # reboot
            return_message[0]="0"
            return_message[1]="0"
            log_info "$(get_current_host_info)_mellanox driver installation and configuration are complete." false
        else
            # 表示未找到mellanox驱动文件
            log_error "$(get_current_host_info)_mellanox driver file is not found, could not install." false
            return_message[0]="3"
        fi
    else
        if [ "${return_message[1]}" == "1" ]; then
            # 启动mellanox网卡驱动
            mst start
        fi
        return_message[1]="0"
        log_info "$(get_current_host_info)_mellanox driver installation and configuration are complete." false
    fi
}

# 安装mellanox驱动
function install_mellanox_result() {
    echo -e ""
    echo -e "\033[33m==================[8]计算节点Mellanox网卡驱动安装配置开始=================\033[0m"
    #install_mellanox &>/dev/null
    install_mellanox
    local return_msg=($(check_mellanox))
    if [ "${return_msg[0]}" == "2" ]; then
        echo -e "\033[33m==\033[0m\033[32m  当前计算节点为虚拟机无需安装Mellanox网卡驱动         [ √ ]\033[0m          \033[33m==\033[0m"
    elif [ "${return_msg[0]}" == "1" ]; then
        echo -e "\033[33m==\033[0m\033[31m  当前计算节点未安装Mellanox网卡驱动                   [ X ]\033[0m          \033[33m==\033[0m"
    else
        if [ "${return_msg[1]}" == "0" ]; then
            echo -e "\033[33m==\033[0m\033[32m  当前计算节点Mellanox网卡驱动已安装且已启动           [ √ ]\033[0m          \033[33m==\033[0m"
        else
            echo -e "\033[33m==\033[0m\033[31m  当前计算节点Mellanox网卡驱动已安装未启动             [ X ]\033[0m          \033[33m==\033[0m"
        fi
    fi
    echo -e "\033[33m==================[8]计算节点Mellanox网卡驱动安装配置结束=================\033[0m"
}

# 脚本执行合法性检查
function required_check() {
    if [ "$(is_physical_machine)" == "0" ]; then
        if [ "$(find_file_by_path ${sourcecode_dir}/ MLNX_OFED_LINUX tgz)" == "" ]; then
            echo -e "\033[31m [${sourcecode_dir}/] directory mellanox driver file does not exist, system exit.\033[0m"
            return 1
        fi
        if [ -n "$(cat /etc/system-release | grep -i Kylin)" ] && [ -z "$(find_file_by_path ${sourcecode_dir}/ tcsh rpm)" ]; then
            echo -e "\033[31m [${sourcecode_dir}/] tcsh dependency package does not exist, system exit.\033[0m"
            return 1
        fi
        if [ -n "$(cat /etc/system-release | grep -i CentOS)" ]; then
            if [ -z "$(yum list | grep tcl)" ]; then
                echo -e "\033[31m [${sourcecode_dir}/] tcl dependency package does not exist from yum source, system exit.\033[0m"
                return 1
            fi
            if [ -z "$(yum list | grep tk)" ]; then
                echo -e "\033[31m [${sourcecode_dir}/] tk dependency package does not exist from yum source, system exit.\033[0m"
                return 1
            fi
            if [ -z "$(yum list | grep pciutils)" ]; then
                echo -e "\033[31m [${sourcecode_dir}/] pciutils dependency package does not exist from yum source, system exit.\033[0m"
                return 1
            fi
            if [ -z "$(yum list | grep lsof)" ]; then
                echo -e "\033[31m [${sourcecode_dir}/] lsof dependency package does not exist from yum source, system exit.\033[0m"
                return 1
            fi
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
manual_script_action ${is_manual_script} ${is_open_debug} required_check check_mellanox_result install_mellanox_result
