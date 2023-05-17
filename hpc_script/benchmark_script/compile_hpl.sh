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
mkdir -p $PWD/tools/benchmark/exec_tools/hpl
mkdir -p $PWD/tools/benchmark/run
hpl_install_path=$PWD/tools/benchmark/exec_tools/hpl
tar -xzf $PWD/sourcecode/hpl*.tar.gz --strip 1 -C $hpl_install_path
log_info "*********解压结束**********" true

#移动benchmark工具测试脚本至对应位置
mv $PWD/tools/hpc_script/benchmark_script/run* $PWD/tools/benchmark/run
#加载module环境变量
source /etc/profile.d/modules.sh

#识别毕昇，hmpi，kml版本号
bisheng_path=`echo $PWD/sourcecode/*compiler*`
hmpi_path=`echo $PWD/sourcecode/Hyper-MPI*`
kml_path=`echo $PWD/sourcecode/BoostKit-kml*`
bisheng_v=`echo "$bisheng_path" | awk -F'/' '{print $5}' | awk -F'-' '{print $3}'`
hmpi_v=`echo "$hmpi_path" | awk -F'/' '{print $5}' | awk -F'_' '{print $2}'`
kml_v=`echo "$kml_path" | awk -F'/' '{print $5}' | awk -F'_' '{print $2}'`

#加载毕昇，hmpi，kml环境变量
module use $PWD/modules
module load compilers/bisheng/$bisheng_v/bisheng$bisheng_v
module load mpi/hmpi/$hmpi_v/bisheng$bisheng_v
module load libs/kml/$kml_v/kml$kml_v

#修改Make.kunpeng配置文件
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

#创建hpl保存编译过程日志目录
touch $hpl_install_path/hpl_compile.log

#编译hpl
cd $hpl_install_path
log_info "*********开始编译**********" true
make arch=kunpeng >> $hpl_install_path/hpl_compile.log
filepath=$PWD/bin/kunpeng/xhpl
if [ -f $filepath ];then
	log_info "*********hpl successfully compiled!**********" true
else
	log_error "*********hpl compiler error**********" true
fi
