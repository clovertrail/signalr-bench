#!/bin/bash
. ./func_env.sh

create_root_folder

. ./jenkins-run-websocket.sh
sh gen_all_report.sh # gen_all_report
sh publish_report.sh 
sh gen_summary.sh # refresh summary.html in NginxRoot gen_summary
sh send_mail.sh $HOME/NginxRoot/$result_root/all.html
