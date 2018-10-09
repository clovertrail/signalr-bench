#!/bin/bash
#input record: 2018-10-09T04:59:01.8227836Z
function count_geneva_time()
{
   local geneva_time_file=$1
   awk -F : '{print $1":"$2}' $geneva_time_file |awk '{s[$0]++}END{for (i in s) print i" " s[i]}'|sort
}

if [ $# -ne 1 ]
then
  echo "Specify the geneva time file extracted from log"
  exit 1
fi

count_geneva_time $1
