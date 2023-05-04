#!/bin/bash
#########处理输入参数######
NP=$1
INPUT_FILE=$2
OTHER_FILE=$3
ln ${INPUT_FILE} .

if [ -f ${OTHER_FILE} ];then
    ln ${OTHER_FILE} .
fi

env
HOSTLIST=`cat ${CCS_ALLOC_FILE} |awk '{print $1,$2}'|sed 's/agent/ragent/g' |sed 's/ /:/g' |tr '\n' ':'`
HOSTLIST=${HOSTLIST%:::}

#######应用脚本路径，按实际情况修改#####
ANSYS_PATH="/home/wangyq/app/ansys_inc/v201/ansys/bin/ansys201"

#####组装mpi命令#####
RUN_CMD="/usr/bin/exagear -- ${ANSYS_PATH} -b -dis -machines $HOSTLIST -np $NP -i ${INPUT_FILE}"

echo $RUN_CMD
$RUN_CMD

ret=$?

if [ $ret -eq 8 ];then
    ret=0
fi
exit $ret
