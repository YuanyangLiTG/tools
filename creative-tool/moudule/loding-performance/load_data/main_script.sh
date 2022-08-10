#!/bin/bash

cwd=$(cd `dirname $0` && pwd)
cd $cwd

source $cwd/../../functions/initial
source ./INPUT

log_file=$cwd/LOG
result_file=$cwd/RESULT
touch $log_file
touch $result_file

function download_ldbc_new() {
  local dpath=$1
  local dsize=$2
  kpath=$(cd $cwd/../ldbc_benchmark/ && pwd)/key.json
  cp $cwd/../ldbc_benchmark/LDBC_10TB/download_one_partition.py $cwd/
  sed -i -e "s|workdir = .*|workdir = \"${dpath}\"|g" $cwd/download_one_partition.py
  cd $cwd
  ori_size=1k
  if [[ "$dsize" == "50" || "$dsize" == "200" || "$dsize" == "500" ]]; then
    python3 download_one_partition.py 1k 0 $((1000/dsize)) -k $kpath -n "true"
  elif [[ "$dsize" == "350" ]]; then
    python3 download_one_partition.py 1k 0 3 -k $kpath -n "true"
  elif [[ "$dsize" == "2000" ]]; then
    ori_size=10k
    python3 download_one_partition.py 10k 0 5 -k $kpath -n "true"
  else
    echo "Failed, Data size $dsize not supported."
    echo "status=failed" >> $result_file
    exit 1
  fi
  cd $dpath
  mv ./sf${ori_size} ./sf${dsize}
  find ./sf${dsize}/ -name *.csv.gz | xargs gunzip
}

if [[ -n "$DATA_URL" && -n "$LOAD_SCRIPT_URL" ]]; then
  if curl -I -H HEAD -s --fail ${DATA_URL} > /dev/null; then
    echo ""
  else
    echo "data download failed" | tee -a $log_file
    exit 1
  fi

  if curl -I -H HEAD -s --fail ${LOAD_SCRIPT_URL} > /dev/null; then
    load_job_0=load_data.gsql
    load_job_1=
    curl -X GET -s ${LOAD_SCRIPT_URL} -o $load_job
  else
    echo "load script download failed" | tee -a $log_file
    exit 1
  fi
else
  if [[ "${DATA_SET}" == "ldbc" ]]; then
    DATA_URL=https://tigergraph-benchmark-dataset.s3-us-west-1.amazonaws.com/LDBC/SF-${DATA_SIZE}/ldbc_snb_data-sf${DATA_SIZE}.tar.gz
    load_job_0=${DATA_SET}_load.gsql
    load_job_1=
  elif [[ "${DATA_SET}" == "tpch" ]]; then
    if [[ "${DATA_SIZE}" == "50" || "${DATA_SIZE}" == "500" ]]; then      
      DATA_URL=https://tigergraph-benchmark-dataset.s3-us-west-1.amazonaws.com/TPCH/SF-${DATA_SIZE}/tpch_${DATA_SIZE}GB.tar.gz
    else
      DATA_URL=https://tigergraph-benchmark-dataset.s3-us-west-1.amazonaws.com/TPCH/SF-${DATA_SIZE}/tpch_sf${DATA_SIZE}.tar.gz
    fi
    load_job_0=${DATA_SET}_load.gsql
    load_job_1=
  elif [[ "${DATA_SET}" == "ldbc_new" ]]; then
    if [[ "${LDBC_FILE_SIZE}" == "small" ]]; then
      DATA_URL=https://storage.googleapis.com/qe-test-data/ldbc-sf${DATA_SIZE}.tar.gz
      load_job_0="special_query/${LDBC_FILE_SIZE}_${TEST_TYPE}.gsql"
    else
      DATA_URL=https://storage.googleapis.com/qe-test-data/social_network-csv_composite-sf${DATA_SIZE}.tar.gz
      load_job_0="special_query/${LDBC_FILE_SIZE}_${TEST_TYPE}.gsql"
    fi
  fi
fi

if [[ -n "${DATA_PATH}" ]]; then
  target_dir=${DATA_PATH}
else
  target_dir=${DOWNLOAD_PATH}
  [[ ! -d "$target_dir" ]] && mkdir -p $target_dir
  cd $target_dir
  if [[ "${DATA_SET}" == "ldbc_new" && -n "$(mount | grep 192.168.99.8)" && "${LDBC_FILE_SIZE}" == "small" ]]; then
    nas_path=$(mount | grep 192.168.99.8 | awk '{print $3}')/data_set/ldbc_bi/
    if [[ ! -d "${nas_path}/sf${DATA_SIZE}" ]]; then
      echo "${nas_path}/sf${DATA_SIZE} not exist, copy data files failed."
      echo "status=failed" >> $result_file
      exit 1
    else
      cp -rf ${nas_path}/sf${DATA_SIZE} $target_dir/
    fi
  else
    if curl -I -H HEAD -s --fail ${DATA_URL} > /dev/null; then
      curl -X GET -s ${DATA_URL} -o $target_dir/data.tar.gz
      tar xzf data.tar.gz
      generate_flag="false"
    else
      if [[ "${DATA_SET}" == "tpch" ]]; then
        echo "Generating data for scale factor "$scale_factor
        curl -X GET -s https://tigergraph-benchmark-dataset.s3-us-west-1.amazonaws.com/TPCH/tpch_2_17_0.tar.gz -o tpch_2_17_0.tar.gz
        tar xzf tpch_2_17_0.tar.gz
        cd tpch_2_17_0/dbgen
        make -f makefile
        ./dbgen -f -s $DATA_SIZE > /dev/null 2>&1
        mv *.tbl $target_dir
      elif [[ "${DATA_SET}" == "ldbc_new" ]]; then
        res=$(download_ldbc_new $target_dir $DATA_SIZE)
        if [[ -n "$(echo ${res} | grep Failed)" ]]; then
          echo "The data size of ${DATA_SIZE} for the data set ${DATA_SET} is invalid, can not download!" | tee -a $log_file
          exit 1
        fi
        generate_flag="true"
      else
        echo "The data size of ${DATA_SIZE} for the data set ${DATA_SET} is invalid, can not download!" | tee -a $log_file
        exit 1
      fi
    fi
  fi
fi
cp $cwd/$load_job_0 $target_dir
if [[ -n "$load_job_1" ]]; then
  cp $cwd/$load_job_1 $target_dir
fi
cd $target_dir

if [[ "${TRANSACTION_ENABLE}" != "false" && -z "$(cat $load_job | grep transaction)" ]]; then
  sed -i -e "s/separator = \"|\"/separator = \"|\", transaction = \"true\"/g" ${cwd}/$load_job_0
  if [[ -n "$load_job_1" ]]; then
    sed -i -e "s/separator = \"|\"/separator = \"|\", transaction = \"true\"/g" ${cwd}/$load_job_1
  fi
fi
gsql_version=$(gsql version | grep version)
install_version=$(echo $gsql_version | awk -F: '{print $2}' | sed "s/ //")
if [[ "${DATA_SET}" == "ldbc_new" ]]; then
  if [[ "${generate_flag}" == "true" ]]; then
    data_dir=$target_dir/sf${DATA_SIZE}/initial_snapshot
  elif [[ "${LDBC_FILE_SIZE}" != "small" ]]; then
    data_dir=$target_dir/social_network-csv_composite-sf${DATA_SIZE}
  else
    data_dir=$target_dir/sf${DATA_SIZE}/csv/bi/composite-projected-fk/initial_snapshot
    rm $target_dir/sf${DATA_SIZE}/csv/bi/composite-projected-fk/initial_snapshot/*/*/_SUCCESS || :
  fi
fi
sed -i -e "s|DATA_PATH|${data_dir}|g" ${cwd}/$load_job_0
if [[ -n "$load_job_1" ]]; then
  sed -i -e "s|DATA_PATH|${data_dir}|g" $load_job_1
fi
count=0
load_log=/tmp/load.tmp
while [[ $count -lt $RUN_TIMES ]]; do
  echo "clear graph store" | tee -a $log_file
  gsql CLEAR GRAPH STORE -HARD | tee -a $log_file
  echo "============================run loading job==========================" | tee -a $log_file
  SECONDS=0
  jobs=1
  if [[ "${DATA_SET}" == "ldbc_new" ]]; then
    jobs=1
  fi
  if [[ -z "${DATA_PATH}" ]]; then
    data_path=$(cd $DOWNLOAD_PATH && pwd)
  else
    data_path=$(cd $DATA_PATH && pwd)
  fi
  index=0
  while [[ "$index" -lt "$jobs" ]]; do
    if [[ "$index" == "0" ]]; then
      gsql ${cwd}/${load_job_0} > $load_log
    elif [[ "$index" == "1" && -n "$load_job_1" ]]; then
      gsql ${load_job_1} > $load_log
    else
      break
    fi
    if [[ -n "$(cat $load_log | grep FAILED)" ]]; then
      grep -A100 "FAILED" $load_log | tee -a $log_file
      echo "status=failed" > $result_file
      exit 1
    elif [[ -n "$(cat $load_log | grep FINISHED)" ]]; then
      grep -A100 "FINISHED" $load_log | tee -a $log_file
      total_lines=$(grep -A100000 "FINISHED" $load_log | grep $data_path | tr -d ' ' | awk -F "|" '{sum+=$3} END {print int(sum)}')
      total_time=$(grep -A100000 "FINISHED" $load_log | grep $data_path | tr -d ' ' | awk -F "|" '{sum+=$5} END {print sum}')
      speed=$(echo "${total_lines}/${total_time}" | bc)
      echo "Total lines: $total_lines" | tee -a $log_file
      echo "lines_${index}_${count}=${total_lines}" >> $result_file
      echo "Total time: $total_time s" | tee -a $log_file
      echo "cost_time_${index}_${count}=${total_time}s" >> $result_file
      echo "Speed: ${speed} l/s" | tee -a $log_file
      echo "load_speed_${index}_${count}=${speed} l/s" >> $result_file
    fi
    echo "The loading process takes time: $SECONDS s" | tee -a $log_file
    check_service_down $log_file
    if [[ -n "$(cat $log_file | grep "Service down:")" ]]; then
      echo "status=failed" >> $result_file
      exit 1
    fi
    index=$((index+1))
  done
  count=$((count+1))
done
echo "status=pass" >> $result_file
if [[ "${SKIP_DELETE_DATA}" == "false" ]]; then
  rm -rf data.tar.gz
  rm -rf *.tbl
  rm -rf ldbc_snb_data
fi