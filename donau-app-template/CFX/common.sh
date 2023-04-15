#!/bin/bash
# Copyright (c) Huawei Technologies Co., Ltd. 2018-2022. All rights reserved.
# Common functions for template.

# Application running command.
if [[ "${VNC_DISPLAY_FLAG}" = "Yes" ]];then
    FDISPLAY="gui"
	SYS_ENV="DISPLAY=${VNC_DISPLAY}"
else
    FDISPLAY="nogui"
fi

NP=${CPU_CORES}
APP_CMD="/share/software/scripts/app/cfx.sh ${FDISPLAY} ${CPU_CORES} ${DEF_FILE} ${RES_FILE}"