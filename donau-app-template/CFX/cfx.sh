#
# Copyright (c) Huawei Technologies Co., Ltd. 2023-2023. All rights reserved.
#

#!/bin/bash

######################################################################
# 脚本描述：cfx应用作业提交脚本                                      #
# 注意事项：无                                                       # 
# 入参说明：$1:VNC可视化标记，$2:核数，$3:def文件，$4:res文件        #
######################################################################
# #运行方式1：【portal】                                             #
#    portal作业模板自动调用，请修改第[3]部分应用路径即可             #
# #运行方式2：【调度器】                                             #
#    调度器dsub提交命令,请修改 [1] 的调度器作业提交参数和 [3] 应用路径
#    然后在CLI节点参考以下命令提交作业：（注：脚本和参数用引号引起） #          
#    dsub -s '/share/script/cfx.sh No 24 Benchmark.def'
######################################################################

#################### [1] 调度器脚本作业命令行提交参数 ################
#DSUB -aa
#DSUB -N 24
#DSUB -ex job
#DSUB --job_type cosched
#DSUB -oo /share/jobdata/ccs_cli/cfx/output_%J_%I.log
#DSUB -eo /share/jobdata/ccs_cli/cfx/error_%J_%I.log 
######################################################################

############################# 调试开关 ###############################
#
#env
######################################################################

######################## [2] 处理输入参数  ###########################
VNC_DISPLAY_FLAG=$1
NP=$2
DEF_FILE=$3
RES_FILE=$4

if [[ "${VNC_DISPLAY_FLAG}" = "Yes" ]];then
    FDISPLAY="-interactive"
else
    FDISPLAY=""
fi

ln ${DEF_FILE} .

HOSTLIST=`cat ${CCS_ALLOC_FILE} |awk '{print $1,$2}'  |tr '\n' ','|sed 's/ /*/g'`
HOSTLIST=${HOSTLIST%,*,}
######################################################################

############# [3] 自定义部分请根据实际情况修改 ######################
#应用命令所在目录按照实际路径修改
CFX_PATH="/share/software/apps/ansys/ansys_inc/v201/CFX/bin/cfx5solve"
######################################################################

######################## [4] 应用命令拼接  ##########################
if [ "x${RES_FILE}" != "x" ]; then
    ln ${RES_FILE} .
    RUN_CMD="${CFX_PATH} -def ${DEF_FILE} -INI-FILE ${RES_FILE} \
            -par -par-dist $HOSTLIST \
            -start-method  'BMI MPI Distributed Parallel' \
            -partition $NP $FDISPLAY"
else
    RUN_CMD="${CFX_PATH} -def ${DEF_FILE} \
            -par -par-dist $HOSTLIST \
            -start-method  'BMI MPI Distributed Parallel' \
            -partition $NP $FDISPLAY"
fi
######################################################################

####################### [5] 应用命令执行及退出  ######################
echo $RUN_CMD
eval $RUN_CMD
ret=$?

exit $ret
######################################################################
