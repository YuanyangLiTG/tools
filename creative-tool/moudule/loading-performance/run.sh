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
  mem_usage=$(ps aux|grep gped|grep -v grep |awk -F ' ' '{print $6}')
  echo "memory_usage: ${mem_usage}" >> ${target_file}
}


ldbc_load_operation() {
  file_size=$1
  load_type=$2

  module_dir=${TEST_MODULE_DIR}/${load_type}

  sed -i -e "s/DATA_SET=.*/DATA_SET=ldbc_new/g" ${module_dir}/INPUT
  sed -i -e "s/LDBC_FILE_SIZE=.*/LDBC_FILE_SIZE=${file_size}/g" ${module_dir}/INPUT

  # test vertex
  sed -i -e "s|TEST_TYPE=.*|TEST_TYPE=vertex|g" ${module_dir}/INPUT
  gsql CLEAR GRAPH STORE -HARD
  echo "------------ldbc_new--$2-$1-vertex-------------" >> ${module_dir}/RESULT
  get_metric ${module_dir}/RESULT
  bash ${module_dir}/main_script.sh
  curl -s -X GET -H "GSQL-TIMEOUT:3600000" "http://localhost:9000/rebuildnow/ldbc_snb"
  sleep 600
  # record info
  get_metric ${module_dir}/RESULT
  echo $(curl -s -H "GSQL-TIMEOUT:600000" -X GET "http://localhost:9000/query/ldbc_snb/vid_attr_sum_ldbc") >> ${module_dir}/RESULT
  gstatusgraph >> ${module_dir}/RESULT
  gsql -g ldbc_snb "select * from Comment limit 100" >> ${module_dir}/ldbc_edge_1.log

  # test edge
  sed -i -e "s|TEST_TYPE=.*|TEST_TYPE=edge|g" ${module_dir}/INPUT
#
#  if [[ "${CLEAR_EXIST_VERTEX}" == "false" ]]; then
#    echo "ignore clear exist vertex"
#  else
#    echo "clear exist vertex"
#    gsql CLEAR GRAPH STORE -HARD
#  fi

  echo "------------ldbc_new--$2-$1-edge-------------" >> ${module_dir}/RESULT
  get_metric ${module_dir}/RESULT
  bash ${module_dir}/main_script.sh
  curl -s -X GET -H "GSQL-TIMEOUT:3600000" "http://localhost:9000/rebuildnow/ldbc_snb"
  sleep 600
  # record info
  get_metric ${module_dir}/RESULT
  echo $(curl -s -H "GSQL-TIMEOUT:600000" -X GET "http://localhost:9000/query/ldbc_snb/vid_attr_sum_ldbc") >> ${module_dir}/RESULT
  gstatusgraph >> ${module_dir}/RESULT
  gsql -g ldbc_snb "select * from Comment limit 100" >> ${module_dir}/ldbc_edge_1.log
}

tpch_load_operation() {
  load_type=$1

  module_dir=${TEST_MODULE_DIR}/${load_type}

  sed -i -e "s/DATA_SET=.*/DATA_SET=tpch/g" ${module_dir}/INPUT
  # test vertex
  sed -i -e "s|TEST_TYPE=.*|TEST_TYPE=vertex|g" ${module_dir}/INPUT
  gsql CLEAR GRAPH STORE -HARD
  cp -rf ${PREPARE_QUERY_DIR}/tpch_data_set/${load_type}/tpch_vertex.gsql ${module_dir}/tpch_load.gsql
  echo "------------tpch--$1-vertex-------------" >> ${module_dir}/RESULT
  get_metric ${module_dir}/RESULT
  bash ${module_dir}/main_script.sh
  curl -s -X GET -H "GSQL-TIMEOUT:3600000" "http://localhost:9000/rebuildnow/tpc_graph"
  sleep 600
  # record info
  get_metric ${module_dir}/RESULT
  echo $(curl -s -H "GSQL-TIMEOUT:600000" -X GET "http://localhost:9000/query/ldbc_snb/vid_attr_sum_ldbc") >> ${module_dir}/RESULT
  gstatusgraph >> ${module_dir}/RESULT
  gsql -g ldbc_snb "select * from Comment limit 100" >> ${module_dir}/tpch_edge_1.log

  # test edge
  sed -i -e "s|TEST_TYPE=.*|TEST_TYPE=edge|g" ${module_dir}/INPUT

#  if [[ "${CLEAR_EXIST_VERTEX}" == "false" ]]; then
#    echo "ignore clear exist vertex"
#  else
#    echo "clear exist vertex"
#    gsql CLEAR GRAPH STORE -HARD
#  fi

  cp -rf ${PREPARE_QUERY_DIR}/tpch_data_set/${load_type}/tpch_edge.gsql ${module_dir}/tpch_load.gsql
  echo "------------tpch--$1-edge-------------" >> ${module_dir}/RESULT
  get_metric ${module_dir}/RESULT
  bash ${module_dir}/main_script.sh
  curl -s -X GET -H "GSQL-TIMEOUT:3600000" "http://localhost:9000/rebuildnow/tpc_graph"
  sleep 600
  # record info
  get_metric ${module_dir}/RESULT
  echo $(curl -s -H "GSQL-TIMEOUT:600000" -X GET "http://localhost:9000/query/ldbc_snb/vid_attr_sum_ldbc") >> ${module_dir}/RESULT
  gstatusgraph >> ${module_dir}/RESULT
  gsql -g ldbc_snb "select * from Comment limit 100" >> ${module_dir}/tpch_edge_1.log
}

run_ldbc(){
  load_1="load_data"
  load_2="concurrent_load"

  # drop all and install ldbc schema
  gsql drop all
  echo "install ldbc schema"
  gsql ${TEST_MODULE_DIR}/create_schema/ldbc_new_schema.gsql

  # install vertex_vid_attr_sum_ldbc.gsql
  echo "install query ---> vertex_vid_attr_sum_ldbc"
  gsql ${cwd}/query/vertex_vid_attr_sum_ldbc.gsql


  echo "start load data ---> small"
  ldbc_load_operation small ${load_1}
  echo "start load data ---> large"
  ldbc_load_operation large ${load_1}


  echo "finished load data"
  curl -X GET https://api.day.app/snLJigKpYsLuzFBZ4waHcb/${current_ip}/ldbc_${load_1}_finished

  echo "start concurrent load ---> small"
  ldbc_load_operation small ${load_2}
  echo "start concurrent load ---> large"
  ldbc_load_operation large ${load_2}
  echo "finished concurrent load"
  curl -X GET https://api.day.app/snLJigKpYsLuzFBZ4waHcb/${current_ip}/ldbc_${load_2}_finished
}


run_tpch(){
  load_1="load_data"
  load_2="concurrent_load"

  # drop all and install ldbc schema
  gsql drop all
  echo "install tpch schema"
  gsql ${TEST_MODULE_DIR}/create_schema/tpch_schema.gsql

  # install vertex_vid_attr_sum.gsql
  echo "install query ---> vertex_vid_attr_sum"
  gsql ${cwd}/query/vertex_vid_attr_sum.gsql

  echo "start load data "
  tpch_load_operation  ${load_1}
  echo "finished load data"
  curl -X GET https://api.day.app/snLJigKpYsLuzFBZ4waHcb/${current_ip}/tpch_${load_1}_finished

  echo "start concurrent load"
  tpch_load_operation  ${load_2}
  echo "finished concurrent load"
  curl -X GET https://api.day.app/snLJigKpYsLuzFBZ4waHcb/${current_ip}/tpch_${load_2}_finished
}



main() {
  run_ldbc
  sleep 600
  run_tpch

}

main
