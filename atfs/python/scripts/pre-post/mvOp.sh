#!/bin/bash

SCRIPT_PATH=`dirname $0`
FILE_NAME=$1
DIR_NAME=`dirname $FILE_NAME`

LOCK_FILE=$SCRIPT_PATH/op.lock

DEST_DIR="/data2/cs_op/"
REC_DEST_DIR="/data2/op_logs/"

if [ -f $LOCK_FILE ]
then
    echo "in process"
    exit 0
fi

touch $LOCK_FILE
ctime=`stat -c %Y $FILE_NAME`

for file in $DIR_NAME/*.dat; do
    echo "mv file ${file}"
    file_ctime=`stat -c %Y ${file}`
    if (( ${file_ctime} <= $ctime  ))
    then
        file_base=`basename $file`
        #day=`echo $file_base | awk -F '_' '{print $3}' | awk -F '.' '{print $1}'`
        cluster=`echo $file_base | awk -F '_' '{print $2}' | cut -c2`
        #send to rerun
        #ssh -p 57764 "mkdir ${REC_DEST_DIR}/${cluster}"
        scp -P 57764 $file rerun:${REC_DEST_DIR}/0${cluster}/
        ssh -p 57764 rerun "touch ${REC_DEST_DIR}/0${cluster}/${file_base}.ok"

        if [ $? -ne 0 ]
        then
            rm -f $LOCK_FILE
            exit 1
        fi
        #mkdir -p ${DEST_DIR}/cs${cluster}
        mv $file ${DEST_DIR}/cs${cluster}/
        #scp -P 57764 ${REC_DEST_DIR}/${day}/bdb.ok storage:${DEST_DIR}/${day}/bdb.ok

   fi
done

rm -f $LOCK_FILE
