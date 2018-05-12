__jenkins_env__="1"
sigbench_run_duration=$Duration
connection_string=$ConnectionString
connection_number=$ClientConnectionNumber
connection_concurrent=$ConcurrentConnectionNumber
send_number=$SendNumber

# verify jenkins input

if [ "$connection_string" == "" ]
then
   echo "connection string must not be empty!"
   exit 1
fi

if [ "$connection_number" == "" ]
then
   echo "connection number must not be empty"
   exit 1
fi

if [ $connection_number -gt 12000 ]
then
   echo "connection number's maximum limit is 12000"
   exit 1
fi

if [ $connection_number -lt 1 ]
then
   echo "connection number's minimum limit is 1"
   exit 1
fi

if [ "$send_number" == "" ]
then
   echo "Warning: send number is empty, so the default send number will be set to connection number"
   send_number=$connection_number
fi

if [ $send_number -gt $connection_number ]
then
   echo "Warning: currently we did not support sending number larger than connection number, so set it to be connection number"
   send_number=$connection_number
fi

# check UseWss
if [[ $connection_string = *"https://"* ]]
then
   use_https=1
else
   use_https=0
fi
