#! /bin/bash -
yest1=`date -d last-day +%Y-%m-%d`
yest2=`date -d last-day +%Y%m%d`
BATCH_DIR="/data1/batch_logs/cs4"
RERUN_BATCH_DIR="/data1/batch_logs/04/${yest2}"
if [ -e $BATCH_DIR/batch.ok ]; then
	ssh -p 57764 rerun "mkdir -p $RERUN_BATCH_DIR"
	scp -P 57764 $BATCH_DIR/cs4_${yest1}_all_batch.tar.gz rerun:$RERUN_BATCH_DIR
	scp -P 57764 $BATCH_DIR/batch.ok rerun:$RERUN_BATCH_DIR
	rm /tmp/rerun_send_batch_4.sh
else
	exit 1
fi
