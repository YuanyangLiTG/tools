#!/bin/bash


#!/bin/bash

cwd=$(cd `dirname $0` && pwd)
cd $cwd

source $cwd/../../functions/initial
source $cwd/INPUT

log_file=$cwd/LOG
result_file=$cwd/RESULT

chaos_dir=/tmp/chaosblade
node_count=$(gssh | grep "Host m" | wc -l)
sed -i -e "s/NODE_COUNT=.*/NODE_COUNT=${node_count}/g" $cwd/create_exp.py
cpu_cores=$(cat /proc/cpuinfo | grep "core id" | wc -l)
sed -i -e "s/CPU_CORE_COUNT=.*/CPU_CORE_COUNT=${cpu_cores}/g" $cwd/create_exp.py
tg_root=$(gadmin config get System.AppRoot)/../../
sed -i -e "s|TG_PATH=.*|TG_PATH=\"${tg_root}\"|g" $cwd/create_exp.py
net_card=$(ifconfig | head -1 | awk -F ':' '{print $1}')
sed -i -e "s/NETCARD=.*/NETCARD=\"${net_card}\"/g" $cwd/create_exp.py
sed -i -e "s/SUDO_PERMISSION=.*/SUDO_PERMISSION=\"${SUDO_PERMISSION}\"/g" $cwd/create_exp.py
sed -i -e "s/EXP_COUNT=.*/EXP_COUNT=${EXP_COUNT}/g" $cwd/create_exp.py


kill_operation_and_monitor(){
  # monitor
  pkill -9 -f crash_monitor
  # operation
  pkill -9 -f keep_loading_tpch
  pkill -9 -f mixed_operations
  pkill -9 -f concurrency_test
}

stop_chaos_test(){
  pkill -9 -f chaos_experiment
}

destroy_all_exps(){
    echo "Starting destroy all exps: $(date)"
    for i in $(seq 1 $node_count); do
        exp_ids=$(grun m$i "$chaos_dir/blade s --type create | /tmp/jq -r '.result|.[]|.Uid+\" \"+.Status+\" \"+.Command'" | grep -iv error | grep -v Destroyed | grep -v Connecting | grep -v network | awk '{print $1}')
        for exp_id in $exp_ids; do
            echo "destroy m$i exp $exp_id"
            grun m$i "$chaos_dir/blade d $exp_id"
        done
        network_exp_ids=$(grun m$i "$chaos_dir/blade s --type create | /tmp/jq -r '.result|.[]|.Uid+\" \"+.Status+\" \"+.Command'" | grep -v Destroyed | grep -v Connecting | grep network | awk '{print $1}')
        for exp_id in $network_exp_ids; do
            echo "destroy m$i exp $exp_id"
            grun m$i "sudo $chaos_dir/blade d $exp_id"
        done
    done
    echo "Finish destroying all exps: $(date)"
    date
}

create_exp(){
    echo "Starting creating exps: $(date)"
    python3 $cwd/create_exp.py "${EXPERIMENTS}" > $cwd/commands
    OLD_IFS="$IFS"
    IFS=$'\n'
    for exp_command in $(cat $cwd/commands); do
        if [[ -n $(echo $exp_command | grep network) ]]; then
            new_command=$(echo $exp_command | sed -e "s|/tmp/chaosblade/blade|sudo /tmp/chaosblade/blade|g")
            echo $new_command
            eval $new_command
        else
            echo $exp_command
            eval $exp_command
        fi
    done
    IFS="$OLD_IFS"
    echo "Finish creating exps: $(date)"
}

destroy_all_exps
gadmin start
wait_service_online 30
res=$(curl -s -H "GSQL-TIMEOUT:300000" "http://localhost:9000/query/tpc_graph/vertex_count")
echo $res | $cwd/../../tools/jq .
if [[ "$(echo $res | $cwd/../../tools/jq .error)" == "true" ]]; then
    echo "failed,result: $res" >> $log_file
    echo "status=failed" >> $result_file
    kill_operation_and_monitor
    stop_chaos_test
    exit 1
fi

echo "Start running experiment" >> $log_file

start_time=$(date '+%s')
runtime=0
while [[ $runtime -lt $DURATION ]]; do
    create_exp | tee -a $log_file
    echo "Wait for ${EXP_INTERVAL}s to destroy and create a new experiment."
    sleep $EXP_INTERVAL
    destroy_all_exps | tee -a $log_file
    gadmin start | tee -a $log_file
    now_time=$(date '+%s')
    runtime=$((now_time-start_time))
done

destroy_all_exps | tee -a $log_file
kill_operation_and_monitor
gadmin start
wait_service_online 600

echo "duration=${runtime}" >> $result_file