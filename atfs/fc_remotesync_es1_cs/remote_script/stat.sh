#!/bin/bash

filename="$1"
ftype="$3"
target="$2"

result=`stat -c "%n,\`echo $target | sed 's/%/\\\\%/g' \`,%s,%Y,\`date +%s\`,\`echo $ftype\`" $filename`
code=$?
echo $result
echo $result > "/tmp/aaa.txt"
exit $?