#!/bin/bash
# Copyright (c) Huawei Technologies Co., Ltd. 2018-2022. All rights reserved.
# Common functions for template.

# Application running command.

SCRIPT_PATH="/share/software/scripts/app/cfx.sh"
APP_CMD="${SCRIPT_PATH} ${VNC_DISPLAY_FLAG} ${CPU_CORES} ${DEF_FILE} ${RES_FILE}"