#!/bin/bash
	
# 引用公共函数文件开始
root_dir=$(echo "$(pwd)" | awk '{split($1,arr,"/");print arr[2]}')
source /${root_dir}/software/tools/hpc_script/common.sh ${root_dir}
# 引用公共函数文件结束

# 脚本合法性检查
function required_check() {
    # 检查安装编译毕昇依赖文件是否存在
    local bisheng_file=$(find_file_by_path /${root_dir}/software/sourcecode/ BiSheng gz)
    if [ -z "${bisheng_file}" ]; then
         log_error "[/${root_dir}/software/sourcecode/] bisheng file doesn't exist, please check." true
         return 1
    fi
    local boostKit_file=$(find_file_by_path /${root_dir}/software/sourcecode/ BoostKit zip)
    if [ -z "${boostKit_file}" ]; then
         log_error "[/${root_dir}/software/sourcecode/] boostKit file doesn't exist, please check." true
         return 1
    fi
    local hyperMpi_file=$(find_file_by_path /${root_dir}/software/sourcecode/ Hyper gz)
    if [ -z "${hyperMpi_file}" ]; then
         log_error "[/${root_dir}/software/sourcecode/] hyper-mpi file doesn't exist, please check." true
         return 1
    fi
    local libatomic_file=$(find_file_by_path /${root_dir}/software/sourcecode/ libatomic rpm)
    if [ -z "${libatomic_file}" ]; then
         log_error "[/${root_dir}/software/sourcecode/] libatomic file doesn't exist, please check." true
         return 1
    fi
    return 0
}

required_check
if [ "$?" == "0" ]; then
    # 设置公共路径
    public_path=$(get_ini_value basic_conf basic_shared_directory /share)/software

    #识别毕昇，hmpi，kml版本号
    cd $public_path
    bisheng_path=`echo $PWD/sourcecode/*compiler*`
    hmpi_path=`echo $PWD/sourcecode/Hyper-MPI*`
    kml_path=`echo $PWD/sourcecode/BoostKit-kml*`
    bisheng_v=`echo "$bisheng_path" | awk -F'/' '{print $5}' | awk -F'-' '{print $3}'`
    hmpi_v=`echo "$hmpi_path" | awk -F'/' '{print $5}' | awk -F'_' '{print $2}'`
    kml_v=`echo "$kml_path" | awk -F'/' '{print $5}' | awk -F'_' '{print $2}'`

    #创建毕昇，hmpi，kml对应目录
    #编译完成后存放目录
    mkdir -p $PWD/compilers/bisheng/$bisheng_v $PWD/mpi/hmpi/$hmpi_v/bisheng$bisheng_v $PWD/libs/kml/$kml_v
    #modulefile文件存放目录
    mkdir -p $PWD/modules/compilers/bisheng/$bisheng_v $PWD/modules/mpi/hmpi/$hmpi_v $PWD/modules/libs/kml/$kml_v
    #安装module
    yum install environment-modules -y -q
    #加载module环境变量
    source /etc/profile.d/modules.sh
    #生成毕昇的modulefile
    prefix='$prefix'
    cat > $PWD/modules/compilers/bisheng/$bisheng_v/bisheng$bisheng_v <<EOF
#%Module

set             version                 $bisheng_v
set             prefix                  $PWD/compilers/bisheng/$bisheng_v

setenv          CC                      clang
setenv          CXX                     clang++
setenv          FC                      flang

prepend-path    PATH                    $prefix/bin
prepend-path    INCLUDE                 $prefix/include
prepend-path    LD_LIBRARY_PATH         $prefix/lib
EOF
    #生成hmpi的modulefile
    cat > $PWD/modules/mpi/hmpi/$hmpi_v/bisheng$bisheng_v <<EOF
#%Module

set version $hmpi_v
set prefix  $PWD/mpi/hmpi/$hmpi_v/bisheng$bisheng_v

setenv MPI_DIR ${prefix}/hmpi
setenv MPI_INC ${prefix}/hmpi/include
setenv MPI_LIB ${prefix}/hmpi/lib
setenv OPAL_PREFIX ${prefix}/hmpi/

prepend-path PATH ${prefix}/hmpi/bin
prepend-path INCLUDE ${prefix}/hmpi/include
prepend-path LD_LIBRARY_PATH ${prefix}/hmpi/lib
prepend-path PATH ${prefix}/hucx/bin
prepend-path INCLUDE ${prefix}/hucx/include
prepend-path LD_LIBRARY_PATH ${prefix}/hucx/lib
EOF
    #生成kml的modulefile
    cat > $PWD/modules/libs/kml/$kml_v/kml$kml_v <<EOF
#%Module

set version $kml_v
set prefix  $PWD/libs/kml/$kml_v

prepend-path LD_LIBRARY_PATH ${prefix}/lib/kblas/omp
EOF

    ###解压毕昇，hmpi，kml的压缩包
    #毕昇
    log_info "=============== Decompressing Bisheng files starts, Please wait ===============" true
    tar --no-same-owner -xzf $bisheng_path --strip 1 -C $PWD/compilers/bisheng/$bisheng_v
    rpm -i $PWD/sourcecode/libatomic*.rpm
    cd $PWD/compilers/bisheng/$bisheng_v
    find . -type f -perm 440 -exec chmod 444 {} \;
    find . -type f -perm 550 -exec chmod 555 {} \;
    #hmpi
    cd $public_path
    tar --no-same-owner -xzf $hmpi_path -C $PWD/mpi/hmpi/$hmpi_v/bisheng$bisheng_v
    #kml
    cd $PWD/sourcecode
    unzip -q BoostKit-kml_*.zip
    rpm --force -i boostkit-kml*.rpm --nodeps
    rm -rf boostkit-kml*.rpm "Kunpeng BoostKit License Agreement 1.0.txt" "鲲鹏应用使能套件BoostKit许可协议 1.0.txt"
    log_info "=============== Decompressing Bisheng files is complete ===============" true

    ### 加载毕昇环境变量
    load_benchmark_env "BiSheng"
    #查看毕昇版本
    log_info "clang -v"
    clang -v
    if [ $? -ne 0 ]; then
      log_error "Bisheng installation and compilation failure." true
    else
      log_info "Bisheng is installed and compiled successfully." true
    fi

    ### 编译HMPI
    ### 安装编译hmpi过程中所依赖的包
    yum -y install -q autoconf automake libtool glibc-devel.aarch64 gcc gcc-c++.aarch64 flex numactl binutils systemd-devel valgrind perl-Data-Dumper
    #执行hmpi编译脚本
    hmpi_install_path=$PWD/mpi/hmpi/$hmpi_v/bisheng$bisheng_v
    HMPI_path=`echo $PWD/mpi/hmpi/$hmpi_v/bisheng$bisheng_v/Hyper-MPI*`
    cd $HMPI_path

    ##### 简单进度条实现方法 #####
    function process() {
        local main_pid=${1}
        local length=40
        local ratio=1
        while [ "$(ps -p ${main_pid} | wc -l)" -ne "1" ]; do
            mark='>'
            process_bar=
            for i in $(seq 1 "${length}") ; do
                if [ ${i} -gt "${ratio}" ]; then
                    mark='-'
                fi
                process_bar=${process_bar}${mark}
            done
            printf "Processing: ${process_bar}\r"
            ratio=$((ratio+1))
            if [ "${ratio}" -gt "${length}" ]; then
                ratio=1
            fi
            sleep 0.5
        done
    }
    ##### 定义安装编译毕生编译器方法（主要用来实现进度条）#####
    function compiler_hmpi() {
        sh hmpi-autobuild.sh -c clang -t release -m hmpi.tar.gz -u hucx.tar.gz -g xucg.tar.gz -p $hmpi_install_path
        if [ $? -ne 0 ]; then
            log_error "Hmpi installation and compilation failure." true
        else
            log_info "Hmpi is installed and compiled successfully." true
        fi
    }

    compiler_hmpi &
    do_hmpi_pid=$(jobs -p | tail -1)
    process "${do_hmpi_pid}" &
    process_pid=$(jobs -p | tail -1)
    wait "${do_hmpi_pid}"

    printf "Processing: done               \n"

    rm -rf $HMPI_path
    #加载hmpi环境变量
    load_benchmark_env "HMPI"
    #查看mpicc路径是否正确
    log_info "which mpirun" true
    which mpirun
    if [ $? -ne 0 ]; then
        log_info "=============== Hmpi path loading failure ===============" true
    else
        log_info "=============== Hmpi path loading successfully ===============" true
    fi
    ###将kml安装生成的目录移至目标路径
    if [ -d "$PWD/libs/kml/" ]; then
        rm -rf $PWD/libs/kml/*
    fi
    mkdir $PWD/libs/kml/$kml_v/
    mv /usr/local/kml/* $PWD/libs/kml/$kml_v/
    #加载kml环境变量
    load_benchmark_env "KML"
fi