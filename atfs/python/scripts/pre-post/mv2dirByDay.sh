#!/bin/bash

SCRIPT_PATH=`dirname $0`
FILE_NAME=$1
DIR_NAME=`dirname $FILE_NAME`
LOCK_FILE=$SCRIPT_PATH/mv.lock
DEST_DIR=""
echo $FILE_NAME

if [ -f $LOCK_FILE ]
then
    exit 0
fi

touch $LOCK_FILE
ctime=`stat -c %Y $FILE_NAME`
for packet in $DIR_NAME/;do
    echo $packet
    packet_ctime=`stat -c %Y $packet`
    if (( $packet_ctime <= $ctime  ))
    then 
        packet_base=`basename $packet`
        day=`echo $packet_base| awk -F '_' '{print $2}'`
        cluster=`echo $packet_base| awk -F '_' '{print $1}'| cut -c3`
        DEST_DIR="/data2/es_logs/0${cluster}/$day/"
        mkdir -p $DEST_DIR
        mv $packet $DEST_DIR
    fi
done

rm -f $LOCK_FILE


