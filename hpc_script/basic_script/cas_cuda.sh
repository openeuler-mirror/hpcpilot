#!/usr/bin/env bash
# 安装CUDA Toolkit自动化脚本

# 引用公共函数文件开始
source /${3}/software/tools/hpc_script/common.sh ${3}
# 引用公共函数文件结束

# 软件存放路径地址
sourcecode_dir=$(get_sourcecode_dir)
# 软件安装路径
cuda_install_path=/usr/local/cuda
# CUDA_Toolkit驱动文件名称
cuda_driver_name=""

# 检查是否安装配置CUDA_Toolkit
function check_cuda() {
    # 2代表当前节点无需安装CUDA_Toolkit 1代表CUDA_Toolkit驱动未安装 0代表CUDA_Toolkit已经安装；
    local ret_install_code="0"
    # 1代表CUDA_Toolkit安装失败 0代表安装成功；
    local ret_test_code="0"
    # 检查判断是否存在GPU卡
    if [ "$(is_gpu_machine)" == "1" ]; then
        log_info "$(get_current_host_info)_the current node does not support installation CUDA_Toolkit." false
        ret_install_code="2"
    else
        # local is_install=$(lsmod | grep nouveau)
        if [ ! -d "${cuda_install_path}/" ] || [ -z "$(cd ${cuda_install_path}/bin && ./nvcc -V)" ]; then
            # 未安装CUDA_Toolkit驱动
            ret_install_code=1
        else
            # 已安装CUDA_Toolkit驱动
            ret_install_code=0
            ############### 检查安装是否成功 ###############
            # 1. 切换到对应目录
            cd ${cuda_install_path}/samples/1_Utilities/deviceQueryDrv
            # 2。检查安装是否成功
            local search_result=$(./deviceQueryDrv | grep PASS)
            if [ -z "${search_result}" ]; then
                log_info "$(get_current_host_info)_CUDA_Toolkit installation failed." false
                ret_test_code="1"
            else
                log_info "$(get_current_host_info)_CUDA_Toolkit has been successfully installed." false
                ret_test_code="0"
            fi
        fi
    fi
    local ret_info=(${ret_install_code} ${ret_test_code})
    echo ${ret_info[@]}
}

# 检查是否安装配置CUDA_Toolkit结果打印输出
function check_cuda_result() {
    echo -e ""
    echo -e "\033[33m==================[9]计算节点CUDAToolkit安装检查结果======================\033[0m"
    local return_msg=($(check_cuda))
    if [ "${return_msg[0]}" == "2" ]; then
        echo -e "\033[33m==\033[0m\033[32m  当前计算节点无需安装CUDA_TOOLKIT网卡驱动             [ √ ]\033[0m          \033[33m==\033[0m"
    elif [ "${return_msg[0]}" == "1" ]; then
        echo -e "\033[33m==\033[0m\033[31m  当前计算节点未安装CUDA_TOOLKIT网卡驱动               [ X ]\033[0m          \033[33m==\033[0m"
    else
        if [ "${return_msg[1]}" == "0" ]; then
            echo -e "\033[33m==\033[0m\033[32m  当前计算节点CUDA_TOOLKIT网卡驱动启动成功             [ √ ]\033[0m          \033[33m==\033[0m"
        else
            echo -e "\033[33m==\033[0m\033[31m  当前计算节点CUDA_TOOLKIT网卡驱动启动失败             [ X ]\033[0m          \033[33m==\033[0m"
        fi
    fi
    echo -e "\033[33m==================[9]计算节点CUDAToolkit安装检查结果======================\033[0m"
}

# 根据不同操作系统安装不同依赖包
function install_cuda_dependency_libs() {
    # 安装麒麟操作系统cuda驱动依赖包
    if [ -n "$(cat /etc/system-release | grep -i Kylin)" ]; then
        if [ "$(rpm -qa gcc-c++)" == "" ]; then
            if [ "$(yum list | grep gcc-c++)" == "" ]; then
                log_error "$(get_current_host_info)_gcc-c++ dependency package does not exist, couldn't install cuda driver." false
            else
                yum install -y gcc-c++
            fi
        fi
    fi
    # 安装欧拉操作系统cuda驱动依赖包
    if [ -n "$(cat /etc/system-release | grep -i openEuler)" ]; then
        if [ "$(rpm -qa gcc-c++)" == "" ]; then
            if [ "$(yum list | grep gcc-c++)" == "" ]; then
                log_error "$(get_current_host_info)_gcc-c++ dependency package does not exist, couldn't install cuda driver." false
            else
                yum install -y gcc-c++
            fi
        fi
    fi
    # 安装CentOS操作系统cuda驱动依赖包
    if [ -n "$(cat /etc/system-release | grep -i CentOS)" ]; then
        # TODO 20230301_待验证CentOS操作系统
        yum install -y gcc-c++
    fi
}

# 安装配置CUDA_Toolkit
function install_cuda() {
    if [ "$(is_gpu_machine)" == "1" ]; then
        log_info "$(get_current_host_info)_the current node does not support installation CUDA_Toolkit." false
    else
        # 查找cuda驱动文件
        cuda_driver_name=$(find_file_by_path ${sourcecode_dir}/ cuda run)
        if [ "${cuda_driver_name}" != "" ]; then
            check_result=($(check_cuda))
            # 已安装且启动失败进行重新安装
            if [ "${check_result[0]}" == "0" ] && [ "${check_result[1]}" == "1" ]; then
                if [ "$(lsmod | grep nouveau)" != "" ]; then
                    # 重新安装CUDA_TOOLKIT网卡驱动
                    # 1. 修改配置文件
                    local search_result=$(cat /etc/modprobe.d/blacklist.conf | grep "blacklist nouveau  options nouveau modeset=0")
                    if [ "${search_result}" == "" ]; then
                        # 追加配置信息到文件中
                        echo -ne "blacklist nouveau  options nouveau modeset=0" >> /etc/modprobe.d/blacklist.conf
                        # 备份刷新initramfs文件
                        mv /boot/initramfs-$(uname -r).img /boot/initramfs-$(uname -r).img.bak
                        dracut /boot/initramfs-$(uname -r).img $(uname -r)
                        # 重启服务
                        # reboot
                    fi
                fi 
            fi
            # 未安装或者启动失败重新安装
            if [ "${check_result[0]}" == "1" ] || [ "${check_result[1]}" == "1" ]; then
                ############### 安装CUDA_TOOLKIT网卡驱动 ###############
                # 0. 安装依赖组件
                install_cuda_dependency_libs
                # 1. 切换到安装包目录
                cd ${sourcecode_dir}
                # 2. 赋予可执行权限
                chmod +x ${cuda_driver_name}
                # 3. 执行安装
                ./${cuda_driver_name} --toolkit --samples --silent --override --driver --installpath=${cuda_install_path}
                # 4. 检查安装是否成功
                cd ${cuda_install_path}/samples/1_Utilities/deviceQueryDrv
                make
                local is_success=$(./deviceQueryDrv | grep PASS)
                if [ -z "${is_success}" ]; then
                    log_info "$(get_current_host_info)_CUDA_Toolkit installation failed." false
                else
                    log_info "$(get_current_host_info)_CUDA_Toolkit has been successfully installed." false
                fi
            fi
        else
            log_error "$(get_current_host_info)_CUDA_Toolkit driver file is not found, could not install." false
        fi  
    fi
}

# 安装配置CUDA_Toolkit结果输出打印
function install_cuda_result() {
    echo -e ""
    echo -e "\033[33m==================[9]计算节点CUDAToolkit安装配置开始======================\033[0m"
    install_cuda
    local return_msg=($(check_cuda))
    if [ "${return_msg[0]}" == "3" ]; then
        echo -e "\033[33m==\033[0m\033[31m  当前计算节点未找到CUDA_TOOLKIT网卡驱动               [ X ]\033[0m          \033[33m==\033[0m"
    elif [ "${return_msg[0]}" == "2" ]; then
        echo -e "\033[33m==\033[0m\033[32m  当前计算节点无需安装CUDA_TOOLKIT网卡驱动             [ √ ]\033[0m          \033[33m==\033[0m"
    elif [ "${return_msg[0]}" == "1" ]; then
        echo -e "\033[33m==\033[0m\033[31m  当前计算节点未安装CUDA_TOOLKIT网卡驱动               [ X ]\033[0m          \033[33m==\033[0m"
    else
        if [ "${return_msg[1]}" == "0" ]; then
            echo -e "\033[33m==\033[0m\033[32m  当前计算节点CUDA_TOOLKIT网卡驱动启动成功             [ √ ]\033[0m          \033[33m==\033[0m"
        else
            echo -e "\033[33m==\033[0m\033[31m  当前计算节点CUDA_TOOLKIT网卡驱动启动失败             [ X ]\033[0m          \033[33m==\033[0m"
        fi
    fi
    echo -e "\033[33m==================[9]计算节点CUDAToolkit安装配置结束======================\033[0m"
}

# 脚本执行合法性检查
function required_check() {
    # 检查判断是否存在GPU卡
    if [ "$(is_gpu_machine)" == "0" ] && [ "$(find_file_by_path ${sourcecode_dir}/ cuda run)" == "" ]; then
        echo -e "\033[31m [${sourcecode_dir}/] directory cuda_toolkit driver file does not exist, system exit.\033[0m"
        return 1  
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
manual_script_action ${is_manual_script} ${is_open_debug} required_check check_cuda_result install_cuda_result