#!/bin/bash

#### 检查运行目录
local_path=$PWD
if [ ! -f "$local_path/$(basename $0)" ];then
    echo "You should run the script in the [SHARE_DIR/benchmark/run] directory."
    exit 1
fi

####主机列表
hostfile=$local_path/hostfile

### 加载环境变量
#识别毕昇，hmpi，kml版本号
cd $PWD/../../../
bisheng_path=`echo $PWD/sourcecode/*compiler*`
hmpi_path=`echo $PWD/sourcecode/Hyper-MPI*`
kml_path=`echo $PWD/sourcecode/BoostKit-kml*`
bisheng_v=`echo "$bisheng_path" | awk -F'/' '{print $5}' | awk -F'-' '{print $3}'`
hmpi_v=`echo "$hmpi_path" | awk -F'/' '{print $5}' | awk -F'_' '{print $2}'`
kml_v=`echo "$kml_path" | awk -F'/' '{print $5}' | awk -F'_' '{print $2}'`

#加载毕昇，hmpi，kml环境变量
source /etc/profile.d/modules.sh
module use $local_path/../../../modules
module load compilers/bisheng/$bisheng_v/bisheng$bisheng_v
module load mpi/hmpi/$hmpi_v/bisheng$bisheng_v
module load libs/kml/$kml_v/kml$kml_v

###HPL测试日志目录
hpl_log_path="$local_path/../logs/hpl_log"
mkdir -p $hpl_log_path

#### 判断执行单机还是集群测试
if [ "x$1" = "xnode" ]; then
    cmd="`which mpirun` --allow-run-as-root -x OMP_NUM_THREADS=8 -x LD_LIBRARY_PATH -x PATH -x PWD -map-by ppr:8:node:pe=1 -mca pml ucx -mca btl ^vader,tcp,openib,uct -mca io romio321 -x UCX_TLS=self,sm,rc -x UCX_NET_DEVICES=mlx5_0:1 ./xhpl" 
    #### 打印信息
    echo "$cmd" >> $hpl_log_path/hpl-$HOSTNAME.log
    ##### 执行单机测试
    cd $local_path/../exec_tools/hpl/bin/kunpeng
    $cmd >> $hpl_log_path/hpl-$HOSTNAME.log
elif [ "x$1" = "xcluster" ]; then
    cmd="`which mpirun` --allow-run-as-root -x OMP_NUM_THREADS=8 -x LD_LIBRARY_PATH -x PATH -x PWD -map-by ppr:16:node:pe=8 -hostfile $hostfile -mca pml ucx -mca btl ^vader,tcp,openib,uct -mca io romio321 -x UCX_TLS=self,sm,rc -x UCX_NET_DEVICES=mlx5_0:1 ./xhpl"
    #### 打印信息
    echo "$cmd" >> $hpl_log_path/hpl-cluster.log
    cat $hostfile >> $hpl_log_path/hpl-cluster.log
    ##### 执行集群测试
    cd $local_path/../exec_tools/hpl/bin/kunpeng
    $cmd >> $hpl_log_path/hpl-cluster.log
else
    echo "$0 node|cluster";
    exit 1
fi
