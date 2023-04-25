#!/bin/bash
# Copyright (c) Huawei Technologies Co., Ltd. 2018-2022. All rights reserved.
# Common functions for template.

# Application running command.
if [[ "${VNC_DISPLAY_FLAG}" = "Yes" ]];then
	SYS_ENV="DISPLAY=${VNC_DISPLAY}"
fi

SCRIPT_PATH="/share/software/script/app/sub_starccm.sh"
APP_CMD="${SCRIPT_PATH} ${CPU_CORES} ${CASE_FILE} ${VNC_DISPLAY_FLAG}"