##! /bin/bash -
yest=`date -d last-day +%Y-%m-%d`
BAK_DIR="/data1/batch_logs/history/"
cd $BAK_DIR
tar zcf cs4_${yest}_all_batch.tar.gz ${yest}_*
scp -P 57764 cs4_${yest}_all_batch.tar.gz msmq:/tmp/
ssh -p 57764 msmq "touch /tmp/cs4_${yest}_all_batch.tar.gz.ok"
rm cs4_${yest}_all_batch.tar.gz
rm /tmp/remote_send_batch.sh
