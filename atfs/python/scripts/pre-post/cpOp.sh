#!/bin/bash
yesterday=`date -d last-day +%Y%m%d`
OP_DIR="/data1/op_file/"
scriptPath=`dirname $0`
DEST_DIR=$1
LOCK_FILE=${scriptPath}/op.lock

hour=`date +%-H`
minute=`date +%-M`

if [ $hour -ne 0 ]
then
    echo "not the time to transfer op_file"
    exit 0
else
    if [ $minute -lt 20 ]
    then
        echo "not the time to transfer op_file"
        exit 0
    fi
fi

if [ -f ${LOCK_FILE} ]
then
    lock_date=`cat ${LOCK_FILE}`
    if [ $lock_date -eq $yesterday ]
    then
        echo "bdb has been transfered"
        exit 0
    fi
fi

cp ${OP_DIR}/${yesterday}/* ${DEST_DIR}
if [ $? -eq 0 ]
then

    echo $yesterday > $LOCK_FILE
    exit 0
fi

exit 1


