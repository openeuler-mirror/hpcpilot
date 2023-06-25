#!/bin/bash

# 引用公共函数文件开始
root_dir=$(echo "$(pwd)" | awk '{split($1,arr,"/");print arr[2]}')
source /${root_dir}/software/tools/hpc_script/common.sh ${root_dir}
# 引用公共函数文件结束

# 脚本合法性检查
function required_check() {
    # 检查安装编译HPL依赖文件是否存在
    local hpl_file=$(find_file_by_path /${root_dir}/software/sourcecode/ hpl gz)
    if [ -z "${hpl_file}" ]; then
         log_error "[/${root_dir}/software/sourcecode/] hpl file doesn't exist, please check." true
         return 1
    fi
    # 检查毕昇是否已安装编译
    load_benchmark_env "BiSheng HMPI KML"
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
    # 检查KML是否已安装编译
    local kml_path=`echo $PWD/sourcecode/BoostKit-kml*`
    local kml_v=`echo "$kml_path" | awk -F'/' '{print $5}' | awk -F'_' '{print $2}'`
    if [ ! -d "/${root_dir}/software/libs/kml/$kml_v/" ]; then
        log_error "Please install and compile KML first." true
        return 1
    fi
    return 0
}

required_check
if [ "$?" == "0" ]; then
    # 设置公共路径
    public_path=$(get_ini_value basic_conf basic_shared_directory /share)/software
    #解压hpl源码包
    log_info "=============== Decompressing Hpl files starts, Please wait ===============" true
    cd $public_path
    if [ -d "$PWD/tools/benchmark/exec_tools/hpl/" ]; then
        rm -rf $PWD/tools/benchmark/exec_tools/hpl
    fi
    mkdir -p $PWD/tools/benchmark/exec_tools/hpl
    mkdir -p $PWD/tools/benchmark/run
    hpl_install_path=$PWD/tools/benchmark/exec_tools/hpl
    tar -xzf $PWD/sourcecode/hpl*.tar.gz --strip 1 -C $hpl_install_path
    log_info "=============== Decompressing Hpl files is complete ===============" true

    # 移动benchmark工具测试脚本至对应位置
    cp -f -p $PWD/tools/hpc_script/benchmark_script/run* $PWD/tools/benchmark/run
    # 加载module环境变量
    load_benchmark_env "BiSheng HMPI KML"

    bisheng_path=`echo $PWD/sourcecode/*compiler*`
    bisheng_v=`echo "$bisheng_path" | awk -F'/' '{print $5}' | awk -F'-' '{print $3}'`
    hmpi_path=`echo $PWD/sourcecode/Hyper-MPI*`
    hmpi_v=`echo "$hmpi_path" | awk -F'/' '{print $5}' | awk -F'_' '{print $2}'`
    kml_path=`echo $PWD/sourcecode/BoostKit-kml*`
    kml_v=`echo "$kml_path" | awk -F'/' '{print $5}' | awk -F'_' '{print $2}'`
    # 修改Make.kunpeng配置文件
    cp $hpl_install_path/setup/Make.Linux_PII_FBLAS $hpl_install_path/Make.kunpeng
    hpl_path=$hpl_install_path/Make.kunpeng
    TOPdir_path=$hpl_install_path
    MPdir_path=`echo $PWD/mpi/hmpi/$hmpi_v/bisheng$bisheng_v/hmpi/`   #根据hmpi版本修改此项内容
    LAlib_path=-L$PWD/libs/kml/$kml_v/lib/kblas/omp/
    sed -i 's/Linux_PII_FBLAS/kunpeng/' $hpl_path
    sed -i "s@TOPdir       =.*@TOPdir       = $TOPdir_path@" $hpl_path
    sed -i "s@MPdir        =.*@MPdir        = $MPdir_path@" $hpl_path
    sed -i 's@MPlib        =.*@MPlib        = -L$(MPdir)/lib/ -lmpi@' $hpl_path
    sed -i 's/LAdir        =.*/LAdir        = /' $hpl_path
    sed -i "s@LAlib        =.*@LAlib        = $LAlib_path -lkblas@" $hpl_path
    sed -i 's/HPL_OPTS     =.*/HPL_OPTS     = -DHPL_DETAILED_TIMING -DHPL_PROGRESS_REPORT/' $hpl_path
    sed -i 's/CC           =.*/CC           = clang/' $hpl_path
    sed -i 's/CCFLAGS      =.*/CCFLAGS      = $(HPL_DEFS) -fomit-frame-pointer -Ofast -ffast-math -ftree-vectorize -mcpu=tsv110  -funroll-loops -W -Wall -fopenmp/' $hpl_path
    sed -i 's/LINKER       =.*/LINKER       = flang/' $hpl_path

    # 创建hpl保存编译过程日志目录
    touch $hpl_install_path/hpl_compile.log

    # 编译hpl
    cd $hpl_install_path
    log_info "=============== Start compiling Hpl, Please wait ===============" true
    make arch=kunpeng >> $hpl_install_path/hpl_compile.log
    filepath=$PWD/bin/kunpeng/xhpl
    if [ -f $filepath ]; then
        log_info "=============== Hpl is installed and compiled successfully ===============" true
    else
        log_error "=============== Hpl installation and compilation failure ===============" true
    fi
fi
