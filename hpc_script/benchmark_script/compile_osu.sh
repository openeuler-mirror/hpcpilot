#!/bin/bash

# 引用公共函数文件开始
root_dir=$(echo "$(pwd)" | awk '{split($1,arr,"/");print arr[2]}')
source /${root_dir}/software/tools/hpc_script/common.sh ${root_dir}
# 引用公共函数文件结束

# 设置公共路径
public_path=$(get_ini_value basic_conf basic_shared_directory /share)/software

#解压hpl源码包
log_info "*********开始解压，请稍等...**********" true
cd $public_path
mkdir -p $PWD/tools/benchmark/exec_tools/osu
osu_install_path=$PWD/tools/benchmark/exec_tools/osu
tar -xzf $PWD/sourcecode/osu* --strip 1 -C $osu_install_path
log_info "*********解压结束**********" true

#加载module环境变量
source /etc/profile.d/modules.sh

#识别毕昇，hmpi，kml版本号
bisheng_path=`echo $PWD/sourcecode/*compiler*`
hmpi_path=`echo $PWD/sourcecode/Hyper-MPI*`
kml_path=`echo $PWD/sourcecode/BoostKit-kml*`
bisheng_v=`echo "$bisheng_path" | awk -F'/' '{print $5}' | awk -F'-' '{print $3}'`
hmpi_v=`echo "$hmpi_path" | awk -F'/' '{print $5}' | awk -F'_' '{print $2}'`

#加载毕昇，hmpi，kml环境变量
module use $PWD/modules
module load compilers/bisheng/$bisheng_v/bisheng$bisheng_v
module load mpi/hmpi/$hmpi_v/bisheng$bisheng_v

#创建osu保存编译过程日志目录
touch $osu_install_path/osu_compile.log

#编译osu
cd $osu_install_path
./configure --prefix=$osu_install_path CC=`which mpicc` CXX=`which mpicxx` >> $osu_install_path/osu_compile.log
make >> $osu_install_path/osu_compile.log
make install >> $osu_install_path/osu_compile.log
if [ -d libexec ]; then
    log_info "osu successfully compiled!" true
else
    log_error "hmpi compiler error" true
fi
