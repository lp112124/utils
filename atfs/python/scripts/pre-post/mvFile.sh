#!/bin/bash

SCRIPT_PATH=`dirname $0`
FILE_NAME=$1
DIR_NAME=`dirname $FILE_NAME`
LOCK_FILE=$SCRIPT_PATH/mv.lock
DEST_DIR=$2
echo $FILE_NAME

if [ -f $LOCK_FILE ]
then
    exit 0
fi

touch $LOCK_FILE
ctime=`stat -c %Y $FILE_NAME`
echo $ctime
for packet in $DIR_NAME/*;do
    packet_ctime=`stat -c %Y $packet`
    echo $packet_ctime
    echo $packet
    if (( $packet_ctime <= $ctime  ))
    then 
        packet_base=`basename $packet`
        day=`echo $packet_base| awk -F '-' '{print $NF}'`
        new_name=${packet_base%-*}
        DEST_DAY_DIR="${DEST_DIR}/${day}"
        mkdir -p $DEST_DAY_DIR
        mv $packet $DEST_DAY_DIR/$new_name
    fi
done

rm -f $LOCK_FILE
