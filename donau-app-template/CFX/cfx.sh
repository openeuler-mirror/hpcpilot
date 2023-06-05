#!/bin/bash

#########处理输入参数#########
if [ $# != 4 ]; then
	echo "Usage: Parameter mismatch."
	exit 1
else
    VNC_DISPLAY_FLAG=$1
	NP=$2
	DEF_FILE=$3
	RES_FILE=$4
fi

if [[ "${VNC_DISPLAY_FLAG}" = "Yes" ]];then
    FDISPLAY="gui"
else
    FDISPLAY="nogui"
fi

ln ${DEF_FILE} .

HOSTLIST=`cat ${CCS_ALLOC_FILE} |awk '{print $1,$2}'  |tr '\n' ','|sed 's/ /*/g'`
HOSTLIST=${HOSTLIST%,*,}

###组装mpirun命令,应用命令所在目录按照实际路径修改
CFX_PATH="/share/software/apps/Ansys20230228/ansys_inc/v201/CFX/bin/cfx5solve"

if [ "x${RES_FILE}" != "x" ]; then
ln ${RES_FILE} .
    RUN_CMD="${CFX_PATH} -def ${DEF_FILE} -INI-FILE ${RES_FILE} -par -par-dist $HOSTLIST -start-method  'Open MPI Distributed Parallel' -partition $NP"
else
	RUN_CMD="${CFX_PATH} -def ${DEF_FILE} -par -par-dist $HOSTLIST -start-method  'Open MPI Distributed Parallel' -partition $NP"
fi

echo $RUN_CMD
eval $RUN_CMD
ret=$?

exit $ret
