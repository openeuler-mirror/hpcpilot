#!/bin/bash
# Copyright (c) Huawei Technologies Co., Ltd. 2018-2022. All rights reserved.
# Common functions for template.

# Application running command.
CASE_DIR=$(dirname $FLUENT_CAS)
CAS_FILE=$(basename $FLUENT_CAS)

FLUENT_OUTNAME=$(echo ${CAS_FILE##*/} | cut -d . -f 1)
FLUENT_OUT="${FLUENT_OUTNAME}@${FLUENT_ITER}"

if [[ "${VNC_DISPLAY_FLAG}" = "Yes" ]];then
    FDISPLAY="gui"
	SYS_ENV="DISPLAY=${VNC_DISPLAY_FLAG}"
else
    FDISPLAY="nogui"
fi

if [[ "${FLUENT_DAT}" = "Yes" ]];then
    DAT_FILE=$(basename $FLUENT_DAT)
	echo "/file/rc
${CAS_FILE}
/file/rd
${DAT_FILE}" > ${JOB_DIR}/fluent_script.jou
else
     echo "/file/rc
${CAS_FILE}" > ${JOB_DIR}/fluent_script.jou
fi

echo "/solve/iterate
${FLUENT_ITER}
/file/wcd
${FLUENT_OUT}
parallel/timer/usage
exit
yes" >> ${JOB_DIR}/fluent_script.jou

SCRIPT_PATH="/home/wangyq/script/fluent.sh"
APP_CMD="${SCRIPT_PATH} ${FLUENT_DIMENSION} ${FDISPLAY} ${CPU_CORES}"