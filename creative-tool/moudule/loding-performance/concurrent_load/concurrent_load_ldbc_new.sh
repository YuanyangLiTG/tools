#!/bin/bash
cwd=$(cd `dirname $0` && pwd)
cd $cwd

source ../../functions/initial
source ../prepare/INPUT
source ../prepare/OUTPUT
source ../install/OUTPUT
source ./INPUT
log_file=$1
result_file=$2

current_nodes=$(gssh | grep -c HostName)
node_array=($(echo ${NODES} | sed -e "s/,/ /g"))
node_num="${#node_array[@]}"
#create schema
if ! gsql ls | grep ldbc_snb; then
    gsql $cwd/../create_schema/ldbc_new_schema.gsql
fi
#down load data
if [[ "${SKIP_CREATE_DATA}" == "true" || "${SKIP_CREATE_DATA}" == "yes" ]]; then
    echo "skip create data since SKIP_CREATE_DATA=${SKIP_CREATE_DATA}" | tee -a $log_file
else
    if [[ "${DATA_SOURCE}" == "/mnt"* && "${LDBC_FILE_SIZE}" == "small" ]]; then
        echo "data source in local, skip download" | tee -a $log_file
    else
        if [[ "${LDBC_FILE_SIZE}" == "small" ]]; then
            DATA_URL=https://storage.googleapis.com/qe-test-data/ldbc-sf${DATA_SIZE}.tar.gz
        else
            DATA_URL=https://storage.googleapis.com/qe-test-data/social_network-csv_composite-sf${DATA_SIZE}.tar.gz
        fi
        echo "download data from $DATA_URL" | tee -a $log_file
        if curl -I -H HEAD -s --fail ${DATA_URL} > /dev/null; then
            curl -X GET -s ${DATA_URL} -o $DATA_PATH/data.tar.gz
            cd $DATA_PATH
            tar xzf data.tar.gz
        else
            echo "$DATA_URL is invalid, test failed" | tee -a $log_file
        fi
    fi
fi

#split data
if [[ "${SKIP_SPLIT_DATA}" == "true" || "${SKIP_SPLIT_DATA}" == "yes" ]]; then
    echo "skip split data since SKIP_SPLIT_DATA=${SKIP_SPLIT_DATA}" | tee -a $log_file
else
    bash $cwd/split_data.sh $log_file
fi

# start service
gadmin start

#concurrent load
if [[ "${LDBC_FILE_SIZE}" == "small" ]]; then
    cp ${cwd}/special_query/${LDBC_FILE_SIZE}_${TEST_TYPE}.gsql $cwd/ldbc_new_load_dynamic_tmp.gsql
else
    cp ${cwd}/special_query/${LDBC_FILE_SIZE}_${TEST_TYPE}.gsql $cwd/ldbc_new_load_dynamic_tmp.gsql
fi
sed -i "s|DATA_PATH|$DATA_PATH|g" ${cwd}/ldbc_new_load_dynamic_tmp.gsql
sed -i "s|sf1|sf$DATA_SIZE|g" ${cwd}/ldbc_new_load_dynamic_tmp.gsql

echo "concurrent loading is in progress..."
SECONDS=0

gsql ${cwd}/ldbc_new_load_dynamic_tmp.gsql > /tmp/load_dynamic.tmp


echo "data_size=${DATA_SIZE}G" >> $result_file
echo "time_cost=${SECONDS}s" >> $result_file
echo "concurrent loading done, cost ${SECONDS}s"

for i in "${!node_array[@]}"; do
    file_count=$(cat /tmp/load_dynamic.tmp | grep "\[FINISHED\] ${node_array[$i]} ( Finished:" | tail -1 | awk '{print $5}')
    line_count=$((file_count+5))
    time=$(cat /tmp/load_dynamic.tmp | grep -A ${line_count} "\[FINISHED\] ${node_array[$i]}" | grep "/dynamic/" | tail -${file_count} | awk -F "|" '{print $5}' | awk '{sum+=$1} END {print sum}')
    lines=$(cat /tmp/load_dynamic.tmp | grep -A ${line_count} "\[FINISHED\] ${node_array[$i]}" | grep "/dynamic/" | tail -${file_count} | awk -F "|" '{print $3}' | awk '{sum+=$1} END {print sum}')
    speed=$(echo "${lines}/${time}" | bc)
    echo "${node_array[$i]}: time_cost: ${time} s, load_speed: ${speed} l/s"
    echo "${node_array[$i]}_time_cost=${time}s" >> $result_file
    echo "${node_array[$i]}_lines=${lines}" >> $result_file
    echo "${node_array[$i]}_speed=${speed}l/s" >> $result_file
done

if [[ ${SECONDS} -le 30 ]]; then
    echo "concurrent load time cost less than 30s, concurrent load failed" | tee -a $log_file
    cat $log_file | grep -i error
else
    echo "${DATA_SIZE}G on $current_nodes nodes concurrent load finished, cost ${SECONDS}s" | tee -a $log_file
fi
