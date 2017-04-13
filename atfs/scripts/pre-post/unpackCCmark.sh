#!/bin/bash

SCRIPT_PATH=`dirname $0`
FILE_NAME=$1
DIR_NAME=`dirname $FILE_NAME`
TMP_DIR=${DIR_NAME}/tmp/
LOCK_FILE=$SCRIPT_PATH/unpack.lock
#DEST_DIR=""
echo $FILE_NAME
if [ ! -d $TMP_DIR ]
then
   mkdir -p $TMP_DIR
fi

if [ -f $LOCK_FILE ]
then
    exit 0
fi

touch $LOCK_FILE
ctime=`stat -c %Y $FILE_NAME`
for packet in $DIR_NAME/*.tar.gz;do
    echo $packet
    packet_ctime=`stat -c %Y $packet`
    if (( $packet_ctime <= $ctime  ))
    then 
	tar -xzvf $packet -C $TMP_DIR
        if [ $? -eq 0 ]
        then
            packet_base=`basename $packet`
            day=`echo $packet_base| awk -F '_' '{print $2}'`
            DEST_DIR="/data5/log/$day/CC/"
            mkdir -p $DEST_DIR
            mv $TMP_DIR/*o* $DEST_DIR
            mv $packet ${DIR_NAME}/history/
        fi
    fi
done

rm -f $LOCK_FILE
