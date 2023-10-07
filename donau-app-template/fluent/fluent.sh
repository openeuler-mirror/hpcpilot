#
# Copyright (c) Huawei Technologies Co., Ltd. 2023-2023. All rights reserved.
#

#!/bin/bash

######################################################################
# 脚本描述：fluent应用作业提交脚本                                   #
# 注意事项：无                                                       # 
# 入参说明：$1:计算维度, $2:VNC可视化标记，$3:核数                   #
######################################################################
#
#env

######################## [1] 处理输入参数  ###########################
# hostfile抓取
export HOSTFILE=/tmp/hostfile.$$
rm -rf $HOSTFILE
touch $HOSTFILE
ntask=`cat ${CCS_ALLOC_FILE} | awk -v fff="$HOSTFILE" '{}
{
	split($0, a, " ")
	if (length(a[1]) > 0 && length(a[3]) > 0) {
		for (i=1;i<=a[2];i++) print a[1] >> fff
    }
}END{print total_task}'`

# 入参
FLUENT_DIMENSION=$1
FDISPLAY=$2
NP=$3

#cat $HOSTFILE

if [ ${FDISPLAY} = "nogui" ];then
    batch="-g"
else
    batch=""
fi

if [ -e "${FLUENT_CAS}" ];then
    ln ${FLUENT_CAS} .
fi

if [ -e "${FLUENT_DAT}" ];then
    ln ${FLUENT_DAT} .
fi
######################################################################

############ [2*] 自定义部分请根据实际情况修改 #######################

# fluent程序路径，根据实际情况修改 
FLUENT_PATH="/share/software/apps/ansys/ansys_inc/v201/fluent/bin/fluent"
######################################################################

######################## [3] 应用命令拼接  ###########################
RUN_CMD="${FLUENT_PATH} ${FLUENT_DIMENSION} ${batch} -t${NP} \
        -cnf=$HOSTFILE -mpi=intel -i fluent_script.jou -affinity=off"
######################################################################

####################### [4] 应用命令执行及退出  ######################
echo $RUN_CMD
eval $RUN_CMD
ret=$?

rm -rf $HOSTFILE
exit $ret
######################################################################
