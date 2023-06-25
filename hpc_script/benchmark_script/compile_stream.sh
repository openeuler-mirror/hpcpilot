#! /bin/bash

# 引用公共函数文件开始
root_dir=$(echo "$(pwd)" | awk '{split($1,arr,"/");print arr[2]}')
source /${root_dir}/software/tools/hpc_script/common.sh ${root_dir}
# 引用公共函数文件结束

# 脚本合法性检查
function required_check() {
    # 检查stream.c文件是否存在
    local streamc_file=/${root_dir}/software/sourcecode/stream.c
    if [ $(is_file_exist ${streamc_file}) == "1" ]; then
        log_error "[${streamc_file}] file doesn't exist, please check." true
        return 1
    fi
    # 检查毕昇是否已安装编译
    load_benchmark_env "BiSheng"
    clang -v 1>/dev/null 2>/dev/null
    if [ $? -ne 0 ]; then
        log_error "Please install and compile BiSheng first." true
        return 1
    fi
    return 0
}

required_check
if [ "$?" == "0" ]; then
    # 设置公共路径
    public_path=$(get_ini_value basic_conf basic_shared_directory /share)/software
    # 解压hpl源码包
    cd $public_path
    mkdir -p $PWD/tools/benchmark/exec_tools/stream
    stream_install_path=$PWD/tools/benchmark/exec_tools/stream
    cp $PWD/sourcecode/stream.c $stream_install_path

    # 加载module环境变量
    load_benchmark_env "BiSheng"
    # 编译stream
    cd $stream_install_path
    clang -fopenmp -O3 -DSTREAM_ARRAY_SIZE=800000000 -DNTIMES=20 -mcmodel=large stream.c -o stream_c.exe
    filepath=$stream_install_path/stream_c.exe
    if [ -f $filepath ];then
    	  log_info "=============== Stream is installed and compiled successfully ===============" true
    else
    	  log_error "=============== Stream installation and compilation failure ===============" true
    fi
fi
