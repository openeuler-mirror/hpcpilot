#!/bin/bash

#======================以下内容无需修改======================
export HOSTFILE=/tmp/hostfile.$$
rm -rf $HOSTFILE
touch $HOSTFILE

cat ${CCS_ALLOC_FILE}
ntask=`cat ${CCS_ALLOC_FILE} | awk -v fff="$HOSTFILE" '{}
{
	split($0, a, " ")
	if (length(a[1]) > 0 && length(a[3]) > 0) {
		for (i=1;i<=a[2];i++) print a[1] >> fff
    }
}END{print total_task}'`
#======================以上内容无需修改======================


FLUENT_DIMENSION=$1
FDISPLAY=$2
NP=$3

cat $HOSTFILE

if [ ${FDISPLAY} = "nogui" ];then
    batch="-g"
else
    batch=""
fi

if [ -e ${FLUENT_CAS} ];then
    ln ${FLUENT_CAS} .
fi

if [ -e ${FLUENT_DAT} ];then
    ln ${FLUENT_DAT} .
fi

env

FLUENT_PATH="/home/wangyq/app/ansys_inc/v201/fluent/bin/fluent"

RUN_CMD="${FLUENT_PATH} ${FLUENT_DIMENSION} ${batch} -t${NP} -cnf=$HOSTFILE -mpi=intel -pib -i fluent_script.jou -affinity=off"

echo $RUN_CMD
eval $RUN_CMD
ret=$?

rm -rf $HOSTFILE
exit $ret
