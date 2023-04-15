#!/bin/bash
# Copyright (c) Huawei Technologies Co., Ltd. 2018-2022. All rights reserved.
# Scheduler parameter combination script.
# The following is an example for submitting built-in system parameters (Avoid parameter conflicts when configuring scheduler parameters) : -o SYS_OUT_PATH -e SYS_ERROR_PATH -n SYS_JOB_NAME –q SYS_JOB_QUEUE -x SYS_ENV -p SYS_PRIORITY.
# Scheduler parameter combination result.
SCHEDULER_PARAMS=""

SCHEDULER_PARAMS="${SCHEDULER_PARAMS} -N {CPU_CORES} -tnp112"


if [ "x${ACCOUNT_NAME}" != "x" ]; then
   SCHEDULER_PARAMS="${SCHEDULER_PARAMS} -A ${ACCOUNT_NAME}"
fi

SCHEDULER_PARAMS="${SCHEDULER_PARAMS} -ex job"
SCHEDULER_PARAMS="${SCHEDULER_PARAMS} --job_type cosched"