#!/bin/bash
. ./env.sh

function log()
{
	echo "$*"
}

## Bourne shell does not support array, so a string is used
## to work around with the hep of awk array

## return the value according to index: 
## @param arr: array (using string)
## @param index: array index (start from 1)
## @param separator: string's separator which is used separate the array item
array_get() {
  local arr=$1
  local index=$2
  local separator=$3
  echo ""|awk -v sep=$separator -v str="$arr" -v idx=$index '{
   split(str, array, sep);
   print array[idx]
}'
}

## return the length of the array
## @param arr: array (using string)
## @param separator: string's separator which is used separate the array item
array_len() {
  local arr=$1
  local separator=$2
  echo ""|awk -v sep=$separator -v str="$arr" '{
   split(str, array, sep);
   print length(array)
}'
}

function iterate_all_bench_server() {
	local callback=$1
	local len=$(array_len "$bench_server_list" "$bench_server_sep")
	local i
	local servers server port user
	i=1
	while [ $i -le $len ]
	do
		servers=$(array_get $bench_server_list $i $bench_server_sep)
		server=$(array_get $servers 1 $bench_server_inter_sep)
		port=$(array_get $servers 2 $bench_server_inter_sep)
		user=$(array_get $servers 3 $bench_server_inter_sep)
		$callback ${server} $port ${user} $i
		i=$(($i+1))
	done
}

function iterate_all_scenarios() {
	local callback=$1
	for i in $bench_name_list
	do
		for j in $bench_type_list
		do
			for k in $bench_codec_list
			do
				local result_name=${j}_${k}_${i}
				$callback $j $k $i #selfhost json echo
			done
		done
	done
}

function gen_single_html
{
	local bench_type=$1
	local bench_codec=$2
	local bench_name=$3

	local resultdir=${bench_type}_${bench_codec}_${bench_name}
	local html_dir=$result_dir/$resultdir
	local norm_file=$result_dir/$resultdir/$sigbench_norm_file
	sh normalize.sh $result_dir/$resultdir/counters.txt $norm_file
	if [ ! -e $html_dir ]
	then
	  mkdir $html_dir
	fi
	go run parseresult.go -input $norm_file -sizerate > $html_dir/latency_rate_size.js
	go run parseresult.go -input $norm_file -rate > $html_dir/latency_rate.js
	go run parseresult.go -input $norm_file -areachart > $html_dir/latency_area.js
	go run parseresult.go -input $norm_file -lastlatency > $html_dir/latency_donut.js
	go run parseresult.go -input $norm_file -lastlatabPercent > $html_dir/latency_table.js
	go run parseresult.go -input $norm_file -category500ms > $html_dir/latency_table_500ms_category.js
	go run parseresult.go -input $norm_file -category1s > $html_dir/latency_table_1s_category.js

	local cmd_prefix=$cmd_config_prefix
	. $sigbench_config_dir/${cmd_prefix}_${bench_codec}_${bench_name}_${bench_type}
	export OnlineConnections=$connection
	export ActiveConnections=$send
	export Duration=$sigbench_run_duration
	export Endpoint=$bench_config_endpoint
	export Hub=$bench_config_hub
	local benchmark=${bench_name}:${bench_type}:${bench_codec}
	export Benchmark=$benchmark
	go run genhtml.go -header="tmpl/header.tmpl" -content="tmpl/content.tmpl" -footer="tmpl/footer.tmpl" > $html_dir/index.html
}

function gen_html() {
	iterate_all_scenarios gen_single_html
}

function gen_all_report() {
for i in `ls $result_dir`
do
   if [ -e $result_dir/$i/latency_table_1s_category.js ]
   then
      sed "s/1s_percent_table_div/${i}_1s_percent_table_div/g" $result_dir/$i/latency_table_1s_category.js > $result_dir/${i}_latency_table_1s_category.js
   fi
   if [ -e $result_dir/$i/latency_table_500ms_category.js ]
   then
      sed "s/500ms_percent_table_div/${i}_500ms_percent_table_div/g" $result_dir/$i/latency_table_500ms_category.js > $result_dir/${i}_latency_table_500ms_category.js
   fi
done

. ./servers_env.sh
export BenchEndpoint=${bench_server}:${bench_server_port}
export SignalRServiceExtSSHEndpoint=${bench_service_pub_server}:${bench_service_pub_port}
export SignalRServiceIntEndpoint=${bench_service_server}:${bench_service_port}
export SignalRDemoAppExtSSHEndpoint=${bench_app_pub_server}:${bench_app_pub_port}
export SignalRDemoAppIntEndpoint=${bench_app_server}:${bench_app_port}

python render_tmpl.py -t tmpl/all.html >$result_dir/all.html
}

function gen_summary_body
{
  local html_root=$1
  local output=$2
  local i
  echo "{{define \"body\"}}" > $output
  for i in `ls -t $html_root`
  do
    is_valid_src=`echo $i|awk '{if ($1 ~ /^[+-]?[0-9]+$/) {print 1;} else {print 0;}}'`
    if [ $is_valid_src == 1 ]
    then
	if [ -e $html_root/$i/all.html ]
	then
		echo "    <div><a href=\"${i}/all.html\">${i} all scenarios</a></div>" >> $output
	else
		for j in `ls $html_root/$i`
		do
			if [ -e $html_root/$i/$j/index.html ]
			then
				echo "    <div><a href=\"${i}/${j}/index.html\">$i</a></div>" >> $output
			fi
		done
	fi
    fi
  done
  echo "{{end}}" >> $output
}

function gen_summary() {
	tmp_sum=/tmp/summary_body.tmpl
	gen_summary_body $nginx_root $tmp_sum
	go run gensummary.go -header="tmpl/header.tmpl" -content="tmpl/summary.tmpl" -body="$tmp_sum" -footer="tmpl/footer.tmpl" > ${nginx_root}/summary.html
}

function prepare
{
	mkdir -p $result_dir
}

function do_single_sigbench() {
	local server=$1
	local port=$2
	local user=$3
	local script=$4
	scp -P $port $script ${user}@${server}:~/$sigbench_home
	ssh -p $port ${user}@${server} "cd $sigbench_home; chmod +x ./$script"
	ssh -p $port ${user}@${server} "cd $sigbench_home; ./$script"
}

function gen_agent_start_stop_script
{
cat << _EOF > $bench_start_file
#!/bin/bash
. ./${sigbench_env_file}

pid=\`cat /tmp/websocket-bench.pid\`
kill -9 \$pid

nohup ./$sigbench_name > \$agent_output 2>&1 &
_EOF

cat << _EOF > $bench_stop_file
pid=\`cat /tmp/websocket-bench.pid\`
kill -9 \$pid
_EOF
}

function append_agents_to_env_file() {
	local server=$1
	local port=$2
	local user=$3
	#localip=`ssh -p $port ${user}@${server} "hostname -I"`
	#localip=`echo "$localip"|awk '{$1=$1};1'`
	local localip=${server}
	# trim whitespace
	localip=`echo "$localip"|awk '{$1=$1};1'`
	if [ "$agents_g" != "" ]
	then
		agents_g=${agents_g}",${localip}:7000"
	else
		agents_g="${localip}:7000"
	fi
}

function gen_websocket_bench_env()
{
	local bench_env=$1
cat << _EOF > $bench_env
#automatic generated file
# for agents
agent_output=$sigbench_agent_output

# for master
selfhost_json_echo=signalr:json:echo
selfhost_msgpack_echo=signalr:msgpack:echo
selfhost_json_broadcast=signalr:json:broadcast
selfhost_msgpack_broadcast=signalr:msgpack:broadcast
service_json_echo=signalr:service:json:echo
service_msgpack_echo=signalr:service:msgpack:echo
service_json_broadcast=signalr:service:json:broadcast
service_msgpack_broadcast=signalr:service:msgpack:broadcast
_EOF

	agents_g=""
	iterate_all_bench_server append_agents_to_env_file
cat << _EOF >> $bench_env
agents="$agents_g"
_EOF
}

function gen_single_cmd_file() {
	local bench_type=$1
	local bench_codec=$2
	local bench_name=$3
	local cmd_prefix="cmd_4"
	
	. $sigbench_config_dir/${cmd_prefix}_${bench_codec}_${bench_name}_${bench_type}
cat << EOF > ${cmd_file_prefix}_${bench_codec}_${bench_name}_${bench_type}
c $connection $connection_concurrent
s $send
wr
w $sigbench_run_duration
EOF
}

function update_jenkins_command_configs()
{
	local bench_type=$1
	local bench_codec=$2
	local bench_name=$3
	local cmd_prefix="cmd_4"
cat << EOF > $sigbench_config_dir/${cmd_prefix}_${bench_codec}_${bench_name}_${bench_type}
connection=$connection_number
connection_concurrent=$connection_concurrent
send=$send_number
EOF
}

function gen_jenkins_command_config()
{
	iterate_all_scenarios update_jenkins_command_configs
}

function gen_cmd_files()
{
	iterate_all_scenarios gen_single_cmd_file
}

function start_single_sigbench
{
	do_single_sigbench $1 $2 $3 $bench_start_file
}

function stop_single_sigbench
{
	do_single_sigbench $1 $2 $3 $bench_stop_file
}

function start_sigbench() {
	iterate_all_bench_server start_single_sigbench
}

function stop_sigbench() {
	iterate_all_bench_server stop_single_sigbench
}

function launch_websocket_master
{
	local script_name=$1
	local server=$2
	local port=$3
	local user=$4
	local status_file=$5
	local remote_run="autogen_runbench.sh"
cat << _EOF > $remote_run
#!/bin/bash
#automatic generated script
echo "0" > $status_file # flag indicates not finish
ssh -p $port ${user}@${server} "cd $sigbench_home; sh $script_name" 2>&1|tee -a ${result_dir}/${script_name}.log
echo "1" > $status_file # flag indicates finished
_EOF
	nohup sh $remote_run &
}

function check_single_agent() {
	local server=$1
	local port=$2
	local user=$3
	local idx=$4
	local agent_log=${result_dir}/${idx}_${sigbench_agent_output}

	if [ "$fail_flag_g" != "" ]
	then
		# already encounter error
		return
	fi
	scp -P $port ${user}@${server}:~/$sigbench_home/$sigbench_agent_output ${agent_log} > /dev/null 2>&1
	fail_flag_g=`egrep -i "fail|error" ${agent_log}`
	if [ "$fail_flag_g" != "" ]
	then
		echo "Error occurs, so break the benchmark, please check ${agent_log}"
	fi
}

function check_and_wait
{
	local flag_file=$1
	local end=$((SECONDS + $sigbench_run_duration))
	local finish=0
	while [ $SECONDS -lt $end ] || [ "$finish" == "0" ]
	do
		# check whether master finished
		finish=`cat $flag_file`
		# check all agents output
		iterate_all_bench_server check_single_agent
		if [ "$fail_flag_g" != "" ]
		then
			break;
		fi
		sleep 1
	done
}

function run_single_master_script_and_check() {
	local bench_type=$1
	local bench_codec=$2
	local bench_name=$3
	
	local result_name=${bench_type}_${bench_codec}_${bench_name}
	local flag_file="master_status.tmp"

	local servers server port user
	# master node
	servers=$(array_get $bench_server_list 1 $bench_server_sep)
	server=$(array_get $servers 1 $bench_server_inter_sep)
	port=$(array_get $servers 2 $bench_server_inter_sep)
	user=$(array_get $servers 3 $bench_server_inter_sep)

	launch_websocket_master ${websocket_script_prefix}_${result_name}.sh $server $port $user $flag_file

	check_and_wait $flag_file
	# fetch result
	scp -r -P $port ${user}@${server}:~/$sigbench_home/$result_name ${result_dir}/
}

function gen_single_websocket_script() {
	local bench_type=$1
	local bench_codec=$2
	local bench_name=$3
	
	local result_name=${bench_type}_${bench_codec}_${bench_name}
	local server_endpoint=${bench_app_pub_server}:${bench_app_port}/${bench_config_hub}

	local wss_option
	if [ $use_https == "1" ]
	then
		wss_option="-u"
	else
		wss_option=""
	fi

cat << EOF > ${websocket_script_prefix}_${result_name}.sh
#auto generated file
. ./$sigbench_env_file
if [ -e ${result_name} ]
then
	rm -rf ${result_name}
fi

if [ -e /tmp/websocket-bench-master.pid ]
then
	pid=\`cat /tmp/websocket-bench-master.pid\`
	kill -9 \$pid
fi

./websocket-bench -m master -a "\${agents}" -s "${server_endpoint}" -t \$${result_name} -c ${cmd_file_prefix}_${bench_codec}_${bench_name}_${bench_type} -o ${result_name} ${wss_option}
EOF
}

function launch_all_websocket_scripts()
{
	iterate_all_scenarios run_single_master_script_and_check
}

function gen_websocket_scripts
{
	iterate_all_scenarios gen_single_websocket_script
}

function gen_websocket_bench
{
	gen_websocket_bench_env $sigbench_env_file
	## generate command files
	gen_cmd_files

	gen_websocket_scripts

	gen_agent_start_stop_script
}

function copy_scripts_to_all_server()
{
	local server=$1
	local port=$2
	local user=$3
	scp -P $port $sigbench_env_file ${user}@${server}:~/${sigbench_home}/
}

function copy_scripts_to_master()
{
	local servers server port user
	# master node
	servers=$(array_get $bench_server_list 1 $bench_server_sep)
	server=$(array_get $servers 1 $bench_server_inter_sep)
	port=$(array_get $servers 2 $bench_server_inter_sep)
	user=$(array_get $servers 3 $bench_server_inter_sep)
	scp -P $port ${websocket_script_prefix}_*.sh ${user}@${server}:~/${sigbench_home}/
	scp -P $port ${cmd_file_prefix}* ${user}@${server}:~/${sigbench_home}/
}

function deploy_all_scripts_config_bench()
{
	copy_scripts_to_master
	iterate_all_bench_server copy_scripts_to_all_server
}

function start_sdk_server()
{
. ./servers_env.sh
	local connection_str="$1"
	local local_run_script="auto_local_launch.sh"
	local remote_run_script="auto_launch_app.sh"
cat << _EOF > $remote_run_script
#!/bin/bash
#automatic generated script
killall dotnet
cd /home/${bench_app_user}/signalr-bench/AzureSignalRChatSample/ChatSample
export Azure__SignalR__ConnectionString="$connection_str"
/home/${bench_app_user}/.dotnet/dotnet run
_EOF

scp -P ${bench_app_pub_port} $remote_run_script ${bench_app_user}@${bench_app_pub_server}:~/

cat << _EOF > $local_run_script
#!/bin/bash
#automatic generated script
ssh -p ${bench_app_pub_port} ${bench_app_user}@${bench_app_pub_server} "sh $remote_run_script"
_EOF

        nohup sh $local_run_script > ${result_dir}/${app_running_log} 2>&1 &

	local end=$((SECONDS + 60))
	local finish=0
	local check
	while [ $SECONDS -lt $end ] && [ "$finish" == "0" ]
	do
		check=`grep "HttpConnection Started" ${result_dir}/${app_running_log}|wc -l`
		if [ "$check" -ge "5" ]
		then
			finish=1
			echo "server is started!"
			break
		else
			echo "wait for server starting..."
		fi
		sleep 1
	done
}
