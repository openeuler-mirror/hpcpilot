#!/bin/bash

#### 检查运行目录
local_path=$PWD
if [ ! -f "$local_path/$(basename $0)" ];then
    echo -e "\033[49;31m you should run the script in the [SHARE_DIR/benchmark/run] directory.\033[0m"
    exit 1
fi

#识别毕昇版本号
cd $PWD/../../../
bisheng_path=`echo $PWD/sourcecode/*compiler*`
bisheng_v=`echo "$bisheng_path" | awk -F'/' '{print $5}' | awk -F'-' '{print $3}'`

#加载毕昇环境变量
source /etc/profile.d/modules.sh
module use $local_path/../../../modules
module load compilers/bisheng/$bisheng_v/bisheng$bisheng_v

#### STREAM测试日志目录
stream_log_path="$local_path/../logs/stream_log"
mkdir -p $stream_log_path

#### 执行测试
export OMP_PROC_BIND=true
if [ -f /sys/kernel/mm/transparent_hugepage/enabled ];then
    hugepage=$(cat /sys/kernel/mm/transparent_hugepage/enabled |grep -o '\[.*\]'|sed 's/\[//'|sed 's/\]//')
    if [ $hugepage != never ];then
	echo never > /sys/kernel/mm/transparent_hugepage/enabled
        $local_path/../tools/stream/stream_c.exe >> $stream_log_path/stream-$HOSTNAME.log
	echo $hugepage > /sys/kernel/mm/transparent_hugepage/enabled
	exit 0
    fi
fi

$local_path/../exec_tools/stream/stream_c.exe >> $stream_log_path/stream-$HOSTNAME.log
