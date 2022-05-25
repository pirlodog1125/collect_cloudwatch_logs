#!/bin/bash
if [ "$1" = "" ]
then
    echo "第1引数にロググループ名を指定して下さい。"
    # 処理を中断。
    exit 1
fi
if [ "$2" = "" ]
then
    echo "第2引数にログストリームのプレフィックスを指定して下さい。"
    # 処理を中断。
    exit 1
fi
if [ "$3" = "" ]
then
    echo "第3引数にどのファイルに結果を出力するかファイル名を指定して下さい。"
    # 処理を中断。
    exit 1
fi
LOG_GROUP_NAME=$1
LOG_STREAM_NAME_PREFIX=$2
OUT_FILE=$3
TEMP_FILE=tmp_`date "+%Y%m%d%H%M%S"`
echo "describe-log-streams..." && \
aws logs describe-log-streams --log-group-name $LOG_GROUP_NAME --log-stream-name-prefix $LOG_STREAM_NAME_PREFIX | jq '.logStreams | sort_by(.lastEventTimestamp)' | grep -e logStreamName | cut -d '"' -f 4 > $TEMP_FILE && \
echo "finished." && \
COUNT=`cat $TEMP_FILE | wc -l` && \
echo "全$COUNT件"
while read LINE;
  do echo "get-log-events... $LINE";
  NEXT_FORWARD_TOKEN=''
  JSON_RESPONSE=$(aws logs get-log-events --log-group-name $LOG_GROUP_NAME --log-stream-name $LINE --start-from-head)
  _NEXT_FORWARD_TOKEN=$(echo $JSON_RESPONSE | jq -r '.nextForwardToken')
  EVENTS=$(echo $JSON_RESPONSE | jq -r '.events')
  echo $EVENTS | jq . >> $OUT_FILE

  while [ ! "$NEXT_FORWARD_TOKEN" = "$_NEXT_FORWARD_TOKEN" ]
  do
    NEXT_FORWARD_TOKEN=$_NEXT_FORWARD_TOKEN
    JSON_RESPONSE=$(aws logs get-log-events --log-group-name $LOG_GROUP_NAME --log-stream-name $LINE --next-token $NEXT_FORWARD_TOKEN)
    _NEXT_FORWARD_TOKEN=$(echo $JSON_RESPONSE | jq -r '.nextForwardToken')
    EVENTS=$(echo $JSON_RESPONSE | jq -r '.events')
    echo $EVENTS | jq . >> $OUT_FILE
  done
  COUNT=`expr $COUNT - 1`
  echo "finished. 残り$COUNT件";
done < $TEMP_FILE
rm $TEMP_FILE
