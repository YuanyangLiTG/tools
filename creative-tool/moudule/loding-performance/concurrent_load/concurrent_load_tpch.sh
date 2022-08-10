cwd=$(cd `dirname $0` && pwd)
cd $cwd

source ../../functions/initial
source ../prepare/INPUT
source ../prepare/OUTPUT
source ../install/OUTPUT
source ./INPUT
log_file=$1
result_file=$2

echo "scp create_load.sh to all node and create tpch data" | tee -a $log_file
gscp all $cwd /tmp

current_nodes=$(gssh | grep -c HostName)
node_array=($(echo ${NODES} | sed -e "s/,/ /g"))
node_num="${#node_array[@]}"
if [[ "${SKIP_CREATE_DATA}" == "true" || "${SKIP_CREATE_DATA}" == "yes" ]]; then
    echo "skip create data since concurrent_load.SKIP_CREATE_DATA=$SKIP_CREATE_DATA"
else
    for i in "${!node_array[@]}"; do
        index=$((i+1))
        if [[ "${node_array[$i]}" == "m1" ]]; then
            bash $cwd/create_data.sh $index $node_num
        else
            c=$(echo "${node_array[$i]}" | sed -e "s/m//")
            ip_add=$(echo $NODE_LIST | awk -F ',' -v i="$c" '{print $i}')
            if [[ "${ATTACH_EFS}" == "true" || "${ATTACH_EFS}" == "yes" ]]; then
                echo "mount efs on m$c"
                if [[ -n "${SUDO_PASSWORD}" ]]; then
                    sshpass -p $SUDO_PASSWORD scp -o $o1 -o $o2 ../prepare/mount_efs.sh $SUDO_USER@$ip_add:/tmp
                    sshpass -p $SUDO_PASSWORD ssh -o $o1 -o $o2 $SUDO_USER@$ip_add "bash /tmp/mount_efs.sh $OS"
                else
                    scp -i $KEY_FILE -o $o1 -o $o2 ../prepare/mount_efs.sh  $SUDO_USER@$ip_add:/tmp
                    ssh -i $KEY_FILE -o $o1 -o $o2 $SUDO_USER@$ip_add "bash /tmp/mount_efs.sh $OS"
                fi
            fi
            if [[ "${ATTACH_S3FS}" == "true" || "${ATTACH_S3FS}" == "yes" ]]; then
                echo "mount s3 on m$c"
                if [[ -n "${SUDO_PASSWORD}" ]]; then
                    sshpass -p $SUDO_PASSWORD scp -o $o1 -o $o2 ../prepare/mount_s3fs.sh $SUDO_USER@$ip_add:/tmp
                    sshpass -p $SUDO_PASSWORD ssh -o $o1 -o $o2 $SUDO_USER@$ip_add "bash /tmp/mount_s3fs.sh $OS"
                else
                    scp -i $KEY_FILE -o $o1 -o $o2 ../prepare/mount_s3fs.sh  $SUDO_USER@$ip_add:/tmp
                    ssh -i $KEY_FILE -o $o1 -o $o2 $SUDO_USER@$ip_add "bash /tmp/mount_s3fs.sh $OS"
                fi
            fi
            echo "create tpch data on m$c"
            nohup grun m$c "bash /tmp/concurrent_load/create_data.sh $index $node_num" &
        fi
    done
    ready=1
    SECONDS=0
    while [[ $ready -eq 1 ]]; do
        if [[ $(grun ${NODES} "ls $DATA_PATH/tpch_data" | grep -c ".tbl") -eq `expr $node_num \* 8` ]]; then
            echo "data created on all nodes"
            ready=0
        else
            echo "create data not finished yet, sleep a minute"
            sleep 300
        fi
        if [[ $SECONDS -ge $TIMEOUT ]]; then
            echo "wait create data timeout"
            ready=2
        fi
    done
fi

if ! gsql ls | grep tpc_graph; then
    gsql $cwd/create_graph.gsql
fi
# start service
gadmin start

echo "start load tpch data on all nodes"
sed -i -e "s|sys.data_root=.*|sys.data_root=\"$DATA_PATH/tpch_data\"|g" tpch_load.gsql
servernames=$(echo ${NODES} | sed -e "s/,/|/g")
sed -i -e "s/all/${servernames}/g" tpch_load.gsql
SECONDS=0
if [[ "${TRANSACTION_ENABLE}" != "false"  && -z $(cat $cwd/$load_job | grep transaction) ]]; then
    sed -i -e 's/separator = \"|\"/separator = \"|\", transaction = \"true\"/g' tpch_load.gsql
    gsql tpch_load.gsql > /tmp/load.tmp
else
    gsql tpch_load.gsql > /tmp/load.tmp
fi
echo "data_size=${DATA_SIZE}G" >> $result_file
echo "time_cost=${SECONDS}s" >> $result_file
if [[ ${SECONDS} -le 30 ]]; then
    echo "concurrent load time cost less than 30s, concurrent load failed" | tee -a $log_file
    cat $log_file | grep -i error
else
    echo "${DATA_SIZE}G on $current_nodes nodes concurrent load finished, cost ${SECONDS}s" | tee -a $log_file
    tail -$(($node_num*14)) /tmp/load.tmp | tee -a $log_file
    for i in "${!node_array[@]}"; do
        time=$(cat /tmp/load.tmp | grep -A 12 "\[FINISHED\] ${node_array[$i]}" | grep tpch_data | tail -8 | awk -F "|" '{print $5}' | awk '{sum+=$1} END {print sum}')
        lines=$(cat /tmp/load.tmp | grep -A 12 "\[FINISHED\] ${node_array[$i]}" | grep tpch_data | tail -8 | awk -F "|" '{print $3}' | awk '{sum+=$1} END {print sum}')
        speed=$(echo "${lines}/${time}" | bc)
        echo "${node_array[$i]}: time_cost: ${time} s, load_speed: ${speed} l/s"
        echo "${node_array[$i]}_time_cost=${time}s" >> $result_file
        echo "${node_array[$i]}_lines=${lines}" >> $result_file
        echo "${node_array[$i]}_speed=${speed}l/s" >> $result_file
    done
fi




