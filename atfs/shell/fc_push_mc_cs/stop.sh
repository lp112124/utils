#!/bin/bash

#################################################
# @Name		ADHai FC Push Module Safe Quit Script
# @Ver		0.02
# @Author	Mac Chow
# @Email	zhouxinghai@adpanshi.com
#################################################

SCRIPT_PATH=`dirname $0`

cd $SCRIPT_PATH

source conf

echo "abort" > $ABORT_FLAG