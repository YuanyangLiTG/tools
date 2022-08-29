#!/bin/bash

cwd=$(cd $(dirname $0) && pwd)
cd $cwd
TEST_MODULE_DIR="/tmp/modularized_test/test_modules"
PREPARE_QUERY_DIR=${cwd}
current_ip=`ip a | grep -Eo "([0-9]{1,3}\.){3}[0-9]{1,3}" | grep -v "127.0.0.1" | grep -Ev "([0-9]{1,3}\.){3}255" | head -n 1`
RESULT_SUM_DIR="/tmp/load_rst"
mkdir -p "${RESULT_SUM_DIR}"
chmod -R 777 ${RESULT_SUM_DIR}

get_metric(){
  target_file=$1
  operation_type=$2
  mem_usage=$(ps aux|grep gped|grep -v grep |awk -F ' ' '{print $6}')
  echo "memory_usage: ${mem_usage}" >> ${target_file}
}

get_process_info(){
  target_file=$1
  operation_type=$2
  gpe_ps_detail=$(grun all "ps aux|grep gped |grep -v grep")
  echo "================GPE=${operation_type}===============:${gpe_ps_detail}"  >> ${target_file}
  gse_ps_detail=$(grun all "ps aux|grep gsed |grep -v grep")
  echo "================GSE=${operation_type}===============:${gse_ps_detail}"  >> ${target_file}
  echo "----------------------------------------------------------------------------------------------------"  >> ${target_file}

}


ldbc_load_operation() {
  file_size=$1
  load_type=$2

  module_dir=${TEST_MODULE_DIR}/${load_type}

  sed -i -e "s/DATA_SET=.*/DATA_SET=ldbc_new/g" ${module_dir}/INPUT
  sed -i -e "s/LDBC_FILE_SIZE=.*/LDBC_FILE_SIZE=${file_size}/g" ${module_dir}/INPUT

  gsql CLEAR GRAPH STORE -HARD
  # test vertex
  sed -i -e "s|TEST_TYPE=.*|TEST_TYPE=vertex|g" ${module_dir}/INPUT
  echo "-------------vertex-------------" >> ${module_dir}/RESULT
  bash ${module_dir}/main_script.sh
  curl -s -X GET -H "GSQL-TIMEOUT:3600000" "http://localhost:9000/rebuildnow/ldbc_snb"
  sleep 1200
  # record info
  echo $(curl -s -H "GSQL-TIMEOUT:600000" -X GET "http://localhost:9000/query/ldbc_snb/vid_attr_sum_ldbc") >> ${module_dir}/RESULT
  gstatusgraph >> ${module_dir}/RESULT
  get_process_info ${module_dir}/process_info "vertex"

  # test edge
  sed -i -e "s|DATA_PATH=.*|DATA_PATH=/home/tigergraph/load_data|g" ${module_dir}/INPUT
  sed -i -e "s|TEST_TYPE=.*|TEST_TYPE=edge|g" ${module_dir}/INPUT
  echo "-------------edge-1------------" >> ${module_dir}/RESULT
  bash ${module_dir}/main_script.sh
  curl -s -X GET -H "GSQL-TIMEOUT:3600000" "http://localhost:9000/rebuildnow/ldbc_snb"
  sleep 1200
  # record info
  echo $(curl -s -H "GSQL-TIMEOUT:600000" -X GET "http://localhost:9000/query/ldbc_snb/vid_attr_sum_ldbc") >> ${module_dir}/RESULT
  gstatusgraph >> ${module_dir}/RESULT
  get_process_info ${module_dir}/process_info "edge-1"

  gsql CLEAR GRAPH STORE -HARD

  #test load edge 2
  sed -i -e "s|TEST_TYPE=.*|TEST_TYPE=edge|g" ${module_dir}/INPUT
  echo "-------------edge-2------------" >> ${module_dir}/RESULT
  bash ${module_dir}/main_script.sh
  curl -s -X GET -H "GSQL-TIMEOUT:3600000" "http://localhost:9000/rebuildnow/ldbc_snb"
  sleep 1200
  # record info
  echo $(curl -s -H "GSQL-TIMEOUT:600000" -X GET "http://localhost:9000/query/ldbc_snb/vid_attr_sum_ldbc") >> ${module_dir}/RESULT
  gstatusgraph >> ${module_dir}/RESULT
  get_process_info ${module_dir}/process_info "edge-2"

 #test load edge 3
  sed -i -e "s|TEST_TYPE=.*|TEST_TYPE=edge|g" ${module_dir}/INPUT
  echo "-------------edge-3------------" >> ${module_dir}/RESULT
  bash ${module_dir}/main_script.sh
  curl -s -X GET -H "GSQL-TIMEOUT:3600000" "http://localhost:9000/rebuildnow/ldbc_snb"
  sleep 1200
  # record info
  echo $(curl -s -H "GSQL-TIMEOUT:600000" -X GET "http://localhost:9000/query/ldbc_snb/vid_attr_sum_ldbc") >> ${module_dir}/RESULT
  gstatusgraph >> ${module_dir}/RESULT
  get_process_info ${module_dir}/process_info "edge-3"

  echo "++++++++++++++++++++++++++++++++++End loading test+++++++++++++++++++++++++++++++++++++++++++++++++" >> ${module_dir}/RESULT
  echo "++++++++++++++++++++++++++++++++++End loading test+++++++++++++++++++++++++++++++++++++++++++++++++" >> ${module_dir}/process_info
}


run_ldbc(){
  load_1="load_data"

  # drop all and install ldbc schema
  gsql drop all
  echo "install ldbc schema"
  gsql ${TEST_MODULE_DIR}/create_schema/ldbc_new_schema.gsql

  # install vertex_vid_attr_sum_ldbc.gsql
  echo "install query ---> vertex_vid_attr_sum_ldbc"
  gsql ${cwd}/query/vertex_vid_attr_sum_ldbc.gsql

  echo "start load data ---> large"
  ldbc_load_operation large ${load_1}

  echo "finished load data"
  curl -X GET https://api.day.app/snLJigKpYsLuzFBZ4waHcb/${current_ip}/ldbc_${load_1}_finished

}




main() {
  run_ldbc
  sleep 600
  run_ldbc

}

main
