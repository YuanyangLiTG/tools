#!/bin/bash


cwd=$(cd `dirname $0` && pwd)
cd $cwd

source ../../functions/initial
source ../prepare/INPUT
source ../prepare/OUTPUT
source ../install/OUTPUT
source ./INPUT

log_file=$cwd/LOG
result_file=$cwd/RESULT
touch $log_file
touch $result_file

echo "start concurrent load test with data_set=$DATA_SET" | tee $log_file
current_nodes=$(gssh | grep -c HostName)
echo "current_nodes=$current_nodes" >> $result_file

if [[ -z "${NODES}" ]]; then
    NODES=$(gssh | grep gpe.servers | awk '{print $2}')
    sed -i -e "s/NODES=.*/NODES=${NODES}/g" $cwd/INPUT
fi

if [ ! -d "${DATA_PATH}" ]; then
    mkdir -p $DATA_PATH
fi

if [ "${DATA_SET}" == "tpch" ];then
    bash concurrent_load_tpch.sh $log_file $result_file
elif [ "${DATA_SET}" == "ldbc_new" ]; then
    bash concurrent_load_ldbc_new.sh $log_file $result_file
else
    echo "only support tpch and ldbc_new data set, concurrent load failed" | tee -a $log_file
fi
# record timestamp of each node
log_dir=$(gadmin config get System.LogRoot)
grun all "grep Destroy $log_dir/fileLoader/RESTPP-LOADER_*.INFO" | grep Destroyed | awk '{print $2}' > $cwd/timestamp
lines=$(cat $cwd/timestamp | wc -l)
if [[ $lines -ge 1 ]]; then
    for i in $(seq $lines)
    do
        timestamp=$(cat $cwd/timestamp | head -$i | tail -1)
        echo "m${i}_finish_time=$timestamp" >> $result_file
    done
else
    echo "no timestamp to record"
fi
sleep 15

if gstatusgraph; then
    gstatusgraph | tee -a $log_file
else
    gadmin status -v graph | tee -a $log_file
fi

if cat $log_file | grep -i "failed"; then
    echo "status=failed" >> $result_file
    echo "some failures during concurrent load, please check $log_file"
    cat $log_file | grep -i "failed"
    exit 1
else
    echo "status=pass" >> $result_file
fi
