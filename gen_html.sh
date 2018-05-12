#!/bin/bash
. ./func_env.sh

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
	#if [ "$bench_type" == "service" ]
	#then
	#	ssh -p $bench_service_pub_port ${bench_service_user}@${bench_service_pub_server} "lscpu" >$html_dir/cpuinfo.txt
	#else
	#	ssh -p $bench_app_pub_port ${bench_app_user}@${bench_app_pub_server} "lscpu" >$html_dir/cpuinfo.txt
	#fi

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

gen_html
