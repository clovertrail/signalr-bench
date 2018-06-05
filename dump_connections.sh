#!/bin/bash

output=/tmp/client_connection.txt
if [ $# -eq 1 ]
then
  output=$1
fi

echo $$ > /tmp/client_connection.pid
echo "" > $output
while [ 1 ]
do
  date_time=`date --iso-8601='seconds'`
  clientconn=`netstat -an|grep 5001|grep EST|wc -l`
  serverconn=`netstat -an|grep 5002|grep EST|wc -l`
  echo "${date_time} $clientconn $serverconn" >> $output
  sleep 1
done
