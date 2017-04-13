#!/bin/bash

SCRIPT_PATH=`dirname $0`
FILE_NAME=$1
DIR_NAME=`dirname $FILE_NAME`

LOCK_FILE=$SCRIPT_PATH/bdb.lock

DEST_DIR="/data2/cc_db/"

if [ -f $LOCK_FILE ]
then
    echo "in process"
    exit 0
fi

touch $LOCK_FILE
ctime=`stat -c %Y $FILE_NAME`

for file in $DIR_NAME/*.tar; do
    echo "mv file ${file}"
    file_ctime=`stat -c %Y ${file}`
    if (( ${file_ctime} <= $ctime  ))
    then
        file_base=`basename $file`
        day=`echo $file_base | awk -F '_' '{print $3}' | awk -F '.' '{print $1}'`
        mkdir -p ${DEST_DIR}/${day}
        mv $file ${DEST_DIR}/${day}/bkdb.tar.gz
        touch ${DEST_DIR}/${day}/bdb.ok
        #send to rerun
        ssh -p 57764 rerun "mkdir ${DEST_DIR}/${day}"
        scp -P 57764 ${DEST_DIR}/${day}/bkdb.tar.gz rerun:${DEST_DIR}/${day}/bkdb.tar.gz
        scp -P 57764 ${DEST_DIR}/${day}/bdb.ok rerun:${DEST_DIR}/${day}/bdb.ok

   fi
done

rm -f $LOCK_FILE
