#!/bin/bash
yesterday=`date -d last-day +%Y%m%d`
BDB_DIR="/data1/cc_db_backup/"
scriptPath=`dirname $0`
DEST_DIR=$1
LOCK_FILE=${scriptPath}/bdb.lock

hour=`date +%-H`
minute=`date +%-M`

if [ $hour -ne 0 ]
then
    echo "not the time to zip bdb"
    exit 1
else
    if [ $minute -lt 20 ]
    then
        echo "not the time to zip bdb"
        exit 1
    fi
fi

if [ -f ${LOCK_FILE} ]
then
    lock_date=`cat ${LOCK_FILE}`
    if [ $lock_date -eq $yesterday ]
    then
        echo "bdb has been transfered"
        exit 1
    fi
fi


if [ -e $BDB_DIR/cc_backup_${yesterday}* ]; then
        #scp -P 57764 $BDB_DIR/cc_backup_$yest* mcmq:/tmp/bkdb.tar.gz
        #ssh -p 57764 mcmq "touch /tmp/bdb.ok"
        cp $BDB_DIR/cc_backup_${yesterday}* ${DEST_DIR}/
        echo $yesterday > $LOCK_FILE
        echo "mv bdb to file"
        exit 0
        #rm /tmp/remote_send_db.sh
else
        echo "no bdb zip packet"
        exit 1
fi

#exit 0

