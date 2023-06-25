#!/bin/bash

# 引用公共函数文件开始
root_dir=$(echo "$(pwd)" | awk '{split($1,arr,"/");print arr[2]}')
source /${root_dir}/software/tools/hpc_script/common.sh ${root_dir}
# 引用公共函数文件结束

# 设置公共路径
public_path=$(get_ini_value basic_conf basic_shared_directory /share)/software
# 脚本合法性检查
function required_check() {
    # 检查安装编译OSU依赖文件是否存在
    local osu_file=$(find_file_by_path /${root_dir}/software/sourcecode/ osu gz)
    if [ -z "${osu_file}" ]; then
         log_error "[/${root_dir}/software/sourcecode/] osu file doesn't exist, please check." true
         return 1
    fi
    load_benchmark_env "BiSheng HMPI"
    clang -v 1>/dev/null 2>/dev/null
    if [ $? -ne 0 ]; then
        log_error "Please install and compile BiSheng first." true
        return 1
    fi
    # 检查HMPI是否已安装编译
    which mpirun 1>/dev/null 2>/dev/null
    if [ $? -ne 0 ]; then
        log_error "Please install and compile HMPI first." true
        return 1
    fi
    return 0
}

required_check
if [ "$?" == "0" ]; then
    #解压hpl源码包
    log_info "=============== Decompressing Osu files starts, Please wait ===============" true
    cd $public_path
    mkdir -p $PWD/tools/benchmark/exec_tools/osu
    osu_install_path=$PWD/tools/benchmark/exec_tools/osu
    tar -xzf $PWD/sourcecode/osu* --strip 1 -C $osu_install_path
    log_info "=============== Decompressing Osu files is complete ===============" true

    #加载module环境变量
    load_benchmark_env "BiSheng HMPI"
    #创建osu保存编译过程日志目录
    touch $osu_install_path/osu_compile.log

    #编译osu
    cd $osu_install_path
    ./configure --prefix=$osu_install_path CC=`which mpicc` CXX=`which mpicxx` >> $osu_install_path/osu_compile.log
    make >> $osu_install_path/osu_compile.log
    make install >> $osu_install_path/osu_compile.log
    if [ -d libexec ]; then
        log_info "=============== Osu is installed and compiled successfully ===============" true
    else
        log_error "=============== Osu installation and compilation failure ===============" true
    fi
fi
