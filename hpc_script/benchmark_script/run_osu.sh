#!/bin/bash

#### 检查运行目录
local_path=$PWD
if [ ! -f "$local_path/$(basename $0)" ];then
    echo -e "\033[49;31m you should run the script in the [SHARE_DIR/benchmark/run] directory.\033[0m"
    exit 1
fi

####主机列表
hostfile=$local_path/hostfile

### 加载环境变量
#识别毕昇，hmpi版本号
cd $PWD/../../../
bisheng_path=`echo $PWD/sourcecode/*compiler*`
hmpi_path=`echo $PWD/sourcecode/Hyper-MPI*`
bisheng_v=`echo "$bisheng_path" | awk -F'/' '{print $5}' | awk -F'-' '{print $3}'`
hmpi_v=`echo "$hmpi_path" | awk -F'/' '{print $5}' | awk -F'_' '{print $2}'`

#加载毕昇，hmpi环境变量
source /etc/profile.d/modules.sh
module use $local_path/../../../modules
module load compilers/bisheng/$bisheng_v/bisheng$bisheng_v
module load mpi/hmpi/$hmpi_v/bisheng$bisheng_v

###OSU测试日志目录
osu_log_path="$local_path/../logs/osu_log"
mkdir -p $osu_log_path

####单节点核数
max_cores=128

case $1 in
   bw)
     osucmd="pt2pt/osu_bw"
     mpi_N=1
     ;;
   latency)
     osucmd="pt2pt/osu_latency"
     mpi_N=1
     ;;
   allreduce)
     osucmd="collective/osu_allreduce"
     mpi_N=$max_cores
     ;;
   bcast)
     osucmd="collective/osu_bcast"
     mpi_N=$max_cores
     ;;
   alltoall)
     osucmd="collective/osu_alltoall"
     mpi_N=$max_cores
     ;;
   *)
     echo "$0 latency|bw|allreduce|bcast|alltoall"
     exit 1
esac

#### 测试命令
cmd="`which mpirun` --allow-run-as-root -N $mpi_N --hostfile $hostfile -x LD_LIBRARY_PATH -x PATH -x PWD -mca pml ucx -mca btl ^vader,tcp,openib,uct -mca io romio321 -x UCX_TLS=self,sm,rc -x UCX_NET_DEVICES=mlx5_0:1 $local_path/../exec_tools/osu/libexec/osu-micro-benchmarks/mpi/$osucmd"

#### 打印信息
echo "$cmd" >> $osu_log_path/osu-$1.log
cat $hostfile >> $osu_log_path/osu-$1.log

#### 执行测试
$cmd >> $osu_log_path/osu-$1.log
