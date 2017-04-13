##! /bin/bash -
yest=`date -d last-day +%Y-%m-%d`
scp /run/adhai_fc/send_data/remote_send_batch.sh cs1:/tmp/
scp -P 57764 /run/adhai_fc/send_data/rerun_send_batch_4.sh storage:/tmp/
ssh cs1 "sh /tmp/remote_send_batch.sh"
if [ -f /tmp/cs4_${yest}_all_batch.tar.gz.ok ];then
	ssh -p 57764 storage "mkdir -p /data1/batch_logs/cs4/"
	scp -P 57764 /tmp/cs4_${yest}_all_batch.tar.gz storage:/data1/batch_logs/cs4
	scp -P 57764 /tmp/cs4_${yest}_all_batch.tar.gz.ok storage:/data1/batch_logs/cs4/batch.ok
	ssh -p 57764 storage "sh /tmp/rerun_send_batch_4.sh"
	rm /tmp/cs4_${yest}_all_batch.tar.gz*
else
	exit 1
fi
