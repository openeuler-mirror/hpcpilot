#!/bin/bash
# Copyright (c) Huawei Technologies Co., Ltd. 2018-2022. All rights reserved.
# Common functions for template.

# Application running command.
if [[ "${VNC_DISPLAY_FLAG}" = "Yes" ]];then
    FDISPLAY=""
	SYS_ENV="DISPLAY=${VNC_DISPLAY_FLAG}"
else
    FDISPLAY="-batch"
fi

NP=${CPU_CORES}
APP_CMD="/share/software/script/app/sub_star_ccm.sh ${NP} ${CASE_FILE} ${FDISPLAY}"