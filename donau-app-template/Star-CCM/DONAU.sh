#!/bin/bash
# Copyright (c) Huawei Technologies Co., Ltd. 2018-2022. All rights reserved.
# Scheduler parameter combination script.
# The following is an example for submitting built-in system parameters (Avoid parameter conflicts when configuring scheduler parameters) : -o SYS_OUT_PATH -e SYS_ERROR_PATH -n SYS_JOB_NAME –q SYS_JOB_QUEUE -x SYS_ENV -p SYS_PRIORITY.
# Scheduler parameter combination result.

#说明：-aa表示忽略架构标签，当提交节点和执行节点架构不一致时，可添加此参数。
SCHEDULER_PARAMS="-aa"

SCHEDULER_PARAMS="${SCHEDULER_PARAMS} -N ${CPU_CORES}"


if [ "x${ACCOUNT_NAME}" != "x" ]; then
   SCHEDULER_PARAMS="${SCHEDULER_PARAMS} -A ${ACCOUNT_NAME}"
fi

SCHEDULER_PARAMS="${SCHEDULER_PARAMS} -ex job"
SCHEDULER_PARAMS="${SCHEDULER_PARAMS} --job_type cosched"