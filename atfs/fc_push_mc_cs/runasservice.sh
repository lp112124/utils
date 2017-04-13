#!/bin/bash

#################################################
# @Name		ADHai FC Push Module Service Script
# @Ver		0.02
# @Author	Mac Chow
# @Email	zhouxinghai@adpanshi.com
#################################################

SCRIPT_PATH=`dirname $0`

nohup "$SCRIPT_PATH/fcpush.sh" > debug.log &

tail -f debug.log