#!/bin/bash

======================以下内容无需修改======================
export HOSTFILE=/tmp/hostfile.$$
rm -rf $HOSTFILE
touch $HOSTFILE

cat ${CCS_ALLOC_FILE}
ntask=`cat ${CCS_ALLOC_FILE} | awk -v fff="$HOSTFILE" '{}
{
	split($0, a, " ")
	if (length(a[1]) > 0 && length(a[3]) > 0) {
		print a[1] >> fff
		total_task+=a[3]
    }
}END{print total_task}'`
======================以上内容无需修改======================

#########处理输入参数#########
if [ $# != 3 ]; then
	echo "Usage: $0 jobname 8 test.k"
	exit 1
else
	NP=$1
	DATA_FILE=$2
	FDISPLAY=$3
fi
ln ${DATA_FILE} .
jobname=`basename ${DATA_FILE}`

HOSTLIST=`cat ${HOSTFILE} |awk '{print $1,$2}'|tr '\n' ','|sed 's/ /:/g'`
HOSTLIST=${HOSTLIST%,:,}
export CDLMD_LICENSE_FILE='/share/software/apps/start-ccm+/path/license.dat'

###组装mpirun命令
export UCX_UD_VERBS_TIMEOUT=30.0m
export UCX_TLS=self,sm,ud
unset SECURITY_NAME
if [ $NP -gt 112 ] ; then
    RUN_CMD="/usr/bin/exagear -- /share/software/apps/star-ccm+/path/15.02.007-R8/STAR-CCM+15.02.007-R8/star/bin/starccm+ $FDISPLAY -np $NP -rsh ssh -on $HOSTLIST -mpi openmpi4 -mpiflags '-mca pml ucx --mca btl ^vader,tcp,ofi,openib,uct --bind-to core' ${jobname}"
else
	RUN_CMD="/usr/bin/exagear -- /share/software/apps/star-ccm+/path/15.02.007-R8/STAR-CCM+15.02.007-R8/star/bin/starccm+ $FDISPLAY -np $NP -rsh ssh -on $HOSTLIST -mpi openmpi4 -mpiflags '--bind-to core' ${jobname}"
fi

echo $RUN_CMD
eval $RUN_CMD
ret=$?

rm -rf $HOSTFILE
exit $ret
