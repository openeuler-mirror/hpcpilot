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
    FDISPLAY=$1
	NP=$2
	DEF_FILE=$3
	RES_FILE=$4
fi
ln ${DEF_FILE} .

HOSTLIST=`cat ${HOSTFILE} |awk '{print $1,$2}'|tr '\n' ','|sed 's/ /*/g'`
HOSTLIST=${HOSTLIST%,*,}

###组装mpirun命令
if [ "x${RES_FILE}" != "x" ]; then
ln ${RES_FILE} .
    RUN_CMD="/usr/bin/exagear -- /share/software/apps/Ansys20230228/ansys_inc/v201/CFX/bin/cfx5solve -def ${DEF_FILE} -INI-FILE ${RES_FILE} -par -par-dist $HOSTFILE -start-method  'Open MPI Distributed Parallel' –partition $NP"
else
	RUN_CMD="/usr/bin/exagear -- /share/software/apps/Ansys20230228/ansys_inc/v201/CFX/bin/cfx5solve -def ${DEF_FILE} -par -par-dist $HOSTFILE -start-method  'Open MPI Distributed Parallel' –partition $NP"
fi

echo $RUN_CMD
eval $RUN_CMD
ret=$?

rm -rf $HOSTFILE
exit $ret
