#
# Copyright (c) Huawei Technologies Co., Ltd. 2023-2023. All rights reserved.
#

#!/bin/bash

######################################################################
# 脚本描述：abaqus应用作业提交脚本                                   #
# 注意事项：运行前请保证license服务可用                              #
# 入参说明：$1:核数, $2:算例文件                                     #
######################################################################
# #运行方式1：【portal】                                             #
#    portal作业模板自动调用，请修改第[3]部分应用路径即可             #
# #运行方式2：【调度器】                                             #
#    调度器dsub提交命令,请修改 [1] 的调度器作业提交参数和 [3] 应用路径
#    然后在CLI节点参考以下命令提交作业：（注：脚本和参数用引号引起） #          
#    dsub -s '/share/script/abaqus.sh 24 e6.inp'                     #
# #运行方式3：【脚本直接运行】                                       #
#    提前在脚本执行路径写好例如abaqus_v6.env的主机列表文件           #
#    列表内容格式参考：                                              #
#    ['host1',20],['host2',20]                                       #
#    在计算节点参考以下命令执行:                                     #
#    /share/script/abaqus.sh 24 e6.inp                               #
######################################################################

#################### [1] 调度器脚本作业命令行提交参数 ################
#DSUB -aa
#DSUB -N 20
#DSUB -ex job
#DSUB --job_type cosched
#DSUB -oo /share/jobdata/ccs_cli/abaqus/output_%J_%I.log
#DSUB -eo /share/jobdata/ccs_cli/abaqus/error_%J_%I.log 
######################################################################

############################# 调试开关 ###############################
#
# env
######################################################################

######################## [2] 处理输入参数  ###########################
NP=$1
CASE_FILE=$2

ln ${CASE_FILE} .
jobname=`basename ${CASE_FILE}`
echo "${HOSTLIST}" >> abaqus_v6.env.test
if [ "${CCS_ALLOC_FILE}" != "" ]; then
	HOSTFILE=hostfile.$$
	awk -v host="$HOSTFILE" '{
		split($0, a, " ")
		if (length(a[1]) > 0 && length(a[3]) > 0) {
	#print a[1]" slots="a[2] >> host
	#print a[1]":"a[2] >> host
	print "[" "'\''"a[1]"'\''"","a[2]"]" >> host
}
}' ${CCS_ALLOC_FILE}
else
	HOSTFILE=hostfile
fi
HOSTLIST=`cat ${HOSTFILE} |tr '\n' ','|sed 's/.$//'`
######################################################################

############ [3] 自定义部分请根据实际情况修改 #######################

### 指定license服务,根据实际情况修改。格式：端口号@ip
export LM_LICENSE_FILE=27500@9.88.46.17

#应用命令所在目录按照实际路径修改
ABQ_PATH="/share/software/apps/abaqus/abaqus/linux_a64/code/bin/ABQLauncher"

######################################################################

######################## [4] 应用命令拼接  ###########################
##注：若需在arm服务器上转码运行，请在命令前加exagear --
RUN_CMD="${ABQ_PATH} \
        job=${jobname} \
        input=${CASE_FILE} \
        cpus=$NP \
        scratch=./ int"
echo "${HOSTLIST}" >> abaqus_v6.env
######################################################################

####################### [5] 应用命令执行及退出  ######################
echo $RUN_CMD
eval $RUN_CMD
ret=$?

rm -rf $HOSTFILE
exit $ret
######################################################################
