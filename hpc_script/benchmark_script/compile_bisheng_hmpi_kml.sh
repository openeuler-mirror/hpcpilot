#!/bin/bash
	
# 引用公共函数文件开始
root_dir=$(echo "$(pwd)" | awk '{split($1,arr,"/");print arr[2]}')
source /${root_dir}/software/tools/hpc_script/common.sh
# 引用公共函数文件结束

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
yum install environment-modules -y
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
echo -e "\033[33m*********开始解压**********\033[0m"
tar --no-same-owner -xzvf $bisheng_path --strip 1 -C $PWD/compilers/bisheng/$bisheng_v
rpm -ivh $PWD/sourcecode/libatomic*.rpm
cd $PWD/compilers/bisheng/$bisheng_v
find . -type f -perm 440 -exec chmod 444 {} \;
find . -type f -perm 550 -exec chmod 555 {} \;
#hmpi
cd $public_path
tar --no-same-owner -xzvf $hmpi_path -C $PWD/mpi/hmpi/$hmpi_v/bisheng$bisheng_v
#kml
cd $PWD/sourcecode
unzip BoostKit-kml_*.zip
rpm --force -ivh boostkit-kml*.rpm --nodeps
rm -rf boostkit-kml*.rpm "Kunpeng BoostKit License Agreement 1.0.txt" "鲲鹏应用使能套件BoostKit许可协议 1.0.txt"
echo -e "\033[33m*********解压完成**********\033[0m"

###加载毕昇环境变量
cd $public_path
module use $PWD/modules
module load compilers/bisheng/$bisheng_v/bisheng$bisheng_v
#查看毕昇版本
echo -e "\e[33mclang -v \e[0m"
clang -v
if [ $? -ne 0 ]; then
	log_error "\e[31mbisheng compiler error \e[0m" true
else
	log_info "\e[32mbisheng successfully compiled! \e" true
fi	

###编译HMPI
#安装编译hmpi过程中所依赖的包
yum -y install autoconf automake libtool glibc-devel.aarch64 gcc gcc-c++.aarch64 flex numactl binutils systemd-devel valgrind perl-Data-Dumper
#执行hmpi编译脚本
hmpi_install_path=$PWD/mpi/hmpi/$hmpi_v/bisheng$bisheng_v
HMPI_path=`echo $PWD/mpi/hmpi/$hmpi_v/bisheng$bisheng_v/Hyper-MPI*`
cd $HMPI_path
sh hmpi-autobuild.sh -c clang -t release -m hmpi.tar.gz -u hucx.tar.gz -g xucg.tar.gz -p $hmpi_install_path
if [ $? -ne 0 ]; then
    log_error "\e[31mhmpi compiler error \e[0m" true
else
    log_info "\e[32mhmpi successfully compiled! \e[0m" true
fi
rm -rf $HMPI_path
#加载hmpi环境变量
cd $public_path
module use $PWD/modules
module load mpi/hmpi/$hmpi_v/bisheng$bisheng_v
#查看mpicc路径是否正确
echo -e "\e[33mwhich mpirun \e[0m"
which mpirun
if [ $? -ne 0 ]; then
    log_error "\e[31mhmpi path loading error \e[0m" true
else
    log_info "\e[32mhmpi path loading correct! \e[0m" true
fi
###将kml安装生成的目录移至目标路径
mv /usr/local/kml/* $PWD/libs/kml/$kml_v
#加载kml环境变量
module use $PWD/modules
module load libs/kml/$kml_v/kml$kml_v
