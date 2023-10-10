#
# Copyright (c) Huawei Technologies Co., Ltd. 2023-2023. All rights reserved.
#

#!/bin/bash

######################################################################
# 脚本描述：starccm应用作业提交脚本                                  #
# 注意事项：无
# 入参说明：$1:核数, $2:算例文件，$3:VNC可视化标记(Yes/No)           #
######################################################################
# #运行方式1：【portal】                                             #
#    portal作业模板自动调用，请修改第[3]部分应用路径即可             #
# #运行方式2：【调度器】                                             #
#    调度器dsub提交命令,请修改 [1] 的调度器作业提交参数和 [3] 应用路径
#    然后在CLI节点参考以下命令提交作业：（注：脚本和参数用引号引起） #          
#    dsub -s '/share/script/sub_starccm.sh 24 A-1.4T-inletsystem-blockqian-case2.sim No'
# #运行方式3：【脚本直接运行】                                       #
#    参考以下命令，额外加入参$4, 为hostfile文件路径                  #
#    hostfile文件内容格式参考： host1:64,host2:64                    #
#    在计算节点参考以下命令执行                                      #
#    /share/software/script/app/sub_starccm.sh 24 casefile  No hostfile
######################################################################

#################### [1] 调度器脚本作业命令行提交参数 ################
#DSUB -aa
#DSUB -N 50
#DSUB -ex job
#DSUB --job_type cosched
#DSUB -oo /share/jobdata/ccs_cli/starccm/output_%J_%I.log
#DSUB -eo /share/jobdata/ccs_cli/starccm/error_%J_%I.log 
######################################################################

############################# 调试开关 ###############################
#
#env
######################################################################

######################## [2] 处理输入参数  ###########################
NP=$1                                                
DATA_FILE=$2                                        
VNC_DISPLAY_FLAG=$3                             
                                                       
if [[ "${VNC_DISPLAY_FLAG}" = "Yes" ]];then           
    FDISPLAY=""                                     
else                                         
    FDISPLAY="-batch"                       
fi 

if [ -z ${CCS_ALLOC_FILE} ]; then
    HOSTLIST=`cat $4`
else
    HOSTLIST=`cat ${CCS_ALLOC_FILE} |awk '{print $1,$2}'|tr '\n' ','|sed 's/ /:/g'`
    HOSTLIST=${HOSTLIST%,:,}
fi

ln ${DATA_FILE} .
casename=`basename ${DATA_FILE}`
######################################################################

############ [3] 自定义部分请根据实际情况修改 #######################

#加载应用license环境变量，按照实际路径修改
export CDLMD_LICENSE_FILE='/share/software/apps/star-ccm+/Siemens/15.04.010-R8/license.dat'

#应用命令所在目录按照实际路径修改
STARCCM_PATH="/share/software/apps/star-ccm+/Siemens/15.04.010-R8/STAR-CCM+15.04.010-R8/star/bin/starccm+"
######################################################################

######################## [4] 应用命令拼接  ###########################
##注：若需在arm服务器上转码运行，请在命令前加exagear --
if [ -z ${CCS_ALLOC_FILE} ]; then
    NODE_NUM=1+`echo $HOSTFILE` | grep -o , | wc -l 
else
    NODE_NUM=`cat ${CCS_ALLOC_FILE} |wc -l`
fi

if [ $NODE_NUM -gt 1 ] ; then
    RUN_CMD="${STARCCM_PATH} $FDISPLAY  \
            -np $NP -rsh ssh -on $HOSTLIST  \
            -mpi openmpi4 -mpiflags '-mca pml ucx  \
            -mca btl ^vader,tcp,ofi,openib,uct' ${casename}"
else
    RUN_CMD="${STARCCM_PATH} $FDISPLAY  \
            -np $NP -rsh ssh -on $HOSTLIST ${casename}"
fi
######################################################################

####################### [5] 应用命令执行及退出  ######################
echo $RUN_CMD
eval $RUN_CMD
ret=$?

exit $ret
######################################################################
