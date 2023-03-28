#! /bin/bash

# 引用公共函数文件开始
root_dir=$(echo "$(pwd)" | awk '{split($1,arr,"/");print arr[2]}')
source /${root_dir}/software/tools/hpc_script/common.sh
# 引用公共函数文件结束

# 设置公共路径
public_path=$(get_ini_value basic_conf basic_shared_directory /share)/software

#解压hpl源码包
cd $public_path
mkdir -p $PWD/tools/benchmark/exec_tools/stream
stream_install_path=$PWD/tools/benchmark/exec_tools/stream
cp $PWD/sourcecode/stream.c $stream_install_path

#识别毕昇版本号
bisheng_path=`echo $PWD/sourcecode/*compiler*`
bisheng_v=`echo "$bisheng_path" | awk -F'/' '{print $5}' | awk -F'-' '{print $3}'`

#加载module环境变量
source /etc/profile.d/modules.sh

#加载毕昇，hmpi，kml环境变量
module use $PWD/modules
module load compilers/bisheng/$bisheng_v/bisheng$bisheng_v

#编译stream
cd $stream_install_path
clang -fopenmp -O3 -DSTREAM_ARRAY_SIZE=800000000 -DNTIMES=20 -mcmodel=large stream.c -o stream_c.exe
filepath=$stream_install_path/stream_c.exe
if [ -f $filepath ];then
	log_info "\033[32m*********stream successfully compiled!**********\033[0m" true
else
	log_error "\033[31m*********stream compiler error**********\033[0m" true
fi
