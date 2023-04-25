#!/bin/bash

#########处理输入参数#########
if [ $# != 3 ]; then
	echo "Usage: Parameter mismatch."
	exit 1
else
	NP=$1
	DATA_FILE=$2
	VNC_DISPLAY_FLAG=$3
fi

if [[ "${VNC_DISPLAY_FLAG}" = "Yes" ]];then
    FDISPLAY=""
	SYS_ENV="DISPLAY=${VNC_DISPLAY}"
else
    FDISPLAY="-batch"
fi

ln ${DATA_FILE} .
jobname=`basename ${DATA_FILE}`

HOSTLIST=`cat ${CCS_ALLOC_FILE} |awk '{print $1,$2}'|tr '\n' ','|sed 's/ /:/g'`
HOSTLIST=${HOSTLIST%,:,}
###此处加载应用license环境变量，按照实际路径修改
export CDLMD_LICENSE_FILE='/share/software/apps/start-ccm+/path/license.dat'

###组装mpirun命令
export UCX_UD_VERBS_TIMEOUT=30.0m
export UCX_TLS=self,sm,ud
unset SECURITY_NAME
###应用命令所在目录按照实际路径修改
STARCCM_PATH="/share/software/apps/star-ccm+/path/15.02.007-R8/STAR-CCM+15.02.007-R8/star/bin/starccm+"

if [ $NP -gt 112 ] ; then
    RUN_CMD="/usr/bin/exagear -- ${STARCCM_PATH} $FDISPLAY -np $NP -rsh ssh -on $HOSTLIST -mpi openmpi4 -mpiflags '-mca pml ucx -mca btl ^vader,tcp,ofi,openib,uct --bind-to core' ${jobname}"
else
	RUN_CMD="/usr/bin/exagear -- ${STARCCM_PATH} $FDISPLAY -np $NP -rsh ssh -on $HOSTLIST -mpi openmpi4 -mpiflags '--bind-to core' ${jobname}"
fi

echo $RUN_CMD
eval $RUN_CMD
ret=$?

exit $ret
