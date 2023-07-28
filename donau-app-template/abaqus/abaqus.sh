#!/bin/bash

#########处理输入参数#########
NP=$1
CASE_FILE=$4
ln ${CASE_FILE} .
jobname=`basename ${CASE_FILE}`

HOSTLIST=`cat ${CCS_ALLOC_FILE} | awk '{print $1,$2}' | sed "s/ /',/" | tr '\n' ']'| sed "s/agent/,'ragent/g"`
HOSTLIST=${HOSTLIST##,}
HOSTLIST=${HOSTLIST%%\',}

ABQ_PATH="/share/software/apps/abaqus/linux_64/code/bin/ABQLauncher"
###组装mpirun命令,应用命令所在目录按照实际路径修改
RUN_CMD="${ABQ_PATH} job=${jobname} input=${CASE_FILE} cpus=$NP scratch=./int"
export LM_LICENSE_FILE=27800@localhost

echo "mp_host_list={$HOSTLIST}" >> abaqus_v6.env

echo $RUN_CMD
eval $RUN_CMD
ret=$?

rm -rf $HOSTFILE
exit $ret
