#!/bin/bash
cluster=3
yesterday=`date -d last-day +%Y-%m-%d`
BATCH_DIR="/data1/batch_logs/history/"
scriptPath=`dirname $0`
DEST_DIR=$1
LOCK_FILE=${scriptPath}/batch.lock

hour=`date +%-H`
minute=`date +%-M`

if [ $hour -ne 0 ]
then
    echo "not the time to zip bdb"
    exit 0
else
    if [ $minute -lt 20 ]
    then
        echo "not the time to zip bdb"
        exit 0
    fi
fi

if [ -f ${LOCK_FILE} ]
then
    lock_date=`cat ${LOCK_FILE}`
    if [ "$lock_date" = "$yesterday" ]
    then
        echo "bdb has been transfered"
        exit 0
    fi
fi

batch_yesterday=`ls ${BATCH_DIR} |grep ${yesterday}.*`
if [ $? -ne 0 ]
then
    echo "no yesterday batch_log"
    exit 0
fi

mkdir -p ${DEST_DIR}
cd ${DEST_DIR}
tar -czvf cs${cluster}_${yesterday}_all_batch.tar.gz -C ${BATCH_DIR} ${batch_yesterday} 
if [ $? -eq 0 ]
then
    echo $yesterday > $LOCK_FILE
    echo "tar batch log success"
    exit 0
else
    echo "tar batch log failed"
    exit 1
fi



