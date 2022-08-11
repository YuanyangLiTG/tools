#!/bin/bash

cwd=$(cd $(dirname $0) && pwd)
cd $cwd
RESULT_DIR="/tmp/lp_rst"
TEST_MODULE_DIR="/tmp/modularized_test/test_modules"
PREPARE_QUERY_DIR=${cwd}
mkdir -p ${RESULT_DIR}

load_data_op() {
  file_size=$1

  sed -i -e "s/LDBC_FILE_SIZE=.*/LDBC_FILE_SIZE=${file_size}/g" ${cwd}/load_data/INPUT

  # test vertex
  sed -i -e "s|DATA_PATH=.*|DATA_PATH=|g" ${cwd}/load_data/INPUT
  sed -i -e "s|TEST_TYPE=.*|TEST_TYPE=vertex|g" ${cwd}/load_data/INPUT
  gsql CLEAR GRAPH STORE -HARD
  echo "--------------$1-vertex-------------" >>${cwd}/load_data/RESULT
  cd ${cwd}/load_data
  bash main_script.sh
  cat ${cwd}/load_data/RESULT >>${RESULT_DIR}/load_data_${file_size}_vertex.rst

  # test edge
  sed -i -e "s|DATA_PATH=.*|DATA_PATH=/home/tigergraph/load_data|g" ${cwd}/load_data/INPUT
  sed -i -e "s|TEST_TYPE=.*|TEST_TYPE=edge|g" ${cwd}/load_data/INPUT
  gsql CLEAR GRAPH STORE -HARD
  echo "--------------$1-edge-------------" >>${cwd}/load_data/RESULT
  cd ${cwd}/load_data;bash main_script.sh

  cat ${cwd}/load_data/RESULT >>${RESULT_DIR}/load_data_${file_size}_edge.rst

}

concurrent_load_op() {
  file_size=$1

  sed -i -e "s/LDBC_FILE_SIZE=.*/LDBC_FILE_SIZE=${file_size}/g" ${cwd}/concurrent_load/INPUT

  # test vertex
  sed -i -e "s|TEST_TYPE=.*|TEST_TYPE=vertex|g" ${cwd}/concurrent_load/INPUT
  gsql CLEAR GRAPH STORE -HARD
  echo "--------------$1-vertex-------------" >>${cwd}/concurrent_load/RESULT
  cd ${cwd}/concurrent_load;bash main_script.sh

  cat ${cwd}/concurrent_load/RESULT >>${RESULT_DIR}/concurrent_load_${file_size}_vertex.rst

  # test edge
  sed -i -e "s|TEST_TYPE=.*|TEST_TYPE=edge|g" ${cwd}/concurrent_load/INPUT
  gsql CLEAR GRAPH STORE -HARD
  echo "--------------$1-edge-------------" >>${cwd}/concurrent_load/RESULT
  cd ${cwd}/concurrent_load
  bash main_script.sh
  cat ${cwd}/concurrent_load/RESULT >>${RESULT_DIR}/concurrent_load_${file_size}_edge.rst

}

ldbc_load_operation() {
  file_size=$1
  load_type=$2

  sed -i -e "s/LDBC_FILE_SIZE=.*/LDBC_FILE_SIZE=${file_size}/g" ${cwd}/${load_type}/INPUT

  # test vertex
  sed -i -e "s|TEST_TYPE=.*|TEST_TYPE=vertex|g" ${cwd}/${load_type}/INPUT
  gsql CLEAR GRAPH STORE -HARD
  echo "--------------$1-vertex-------------" >>${cwd}/${load_type}/RESULT
  bash ${cwd}/${load_type}/main_script.sh
  cat ${cwd}/${load_type}/RESULT >>${RESULT_DIR}/${load_type}_${file_size}_vertex.rst

  # test edge
  sed -i -e "s|TEST_TYPE=.*|TEST_TYPE=edge|g" ${cwd}/${load_type}/INPUT
  gsql CLEAR GRAPH STORE -HARD
  echo "--------------$1-edge-------------" >>${cwd}/${load_type}/RESULT
  bash ${cwd}/${load_type}/main_script.sh
  cat ${cwd}/${load_type}/RESULT >>${RESULT_DIR}/${load_type}_${file_size}_edge.rst
}

tpch_load_operation() {
  load_type=$1

  sed -i -e "s/DATA_SET=.*/DATA_SET=tpch/g" ${cwd}/${load_type}/INPUT
  # test vertex
  sed -i -e "s|TEST_TYPE=.*|TEST_TYPE=vertex|g" ${cwd}/${load_type}/INPUT
  gsql CLEAR GRAPH STORE -HARD
  cp -rf ${PREPARE_QUERY_DIR}/tpch_data_set/${load_type}/tpch_edge.gsql ${TEST_MODULE_DIR}/${load_type}/tpch_load.gsql
  echo "--------------$1-vertex-------------" >>${cwd}/${load_type}/RESULT
  bash ${cwd}/${load_type}/main_script.sh
  cat ${cwd}/${load_type}/RESULT >>${RESULT_DIR}/${load_type}_${file_size}_vertex.rst

  # test edge
  sed -i -e "s|TEST_TYPE=.*|TEST_TYPE=edge|g" ${cwd}/${load_type}/INPUT
  gsql CLEAR GRAPH STORE -HARD
  cp -rf ${PREPARE_QUERY_DIR}/tpch_data_set/${load_type}/tpch_vertex.gsql ${TEST_MODULE_DIR}/${load_type}/tpch_load.gsql
  echo "--------------$1-edge-------------" >>${cwd}/${load_type}/RESULT
  bash ${cwd}/${load_type}/main_script.sh
  cat ${cwd}/${load_type}/RESULT >>${RESULT_DIR}/${load_type}_${file_size}_edge.rst
}

run_ldbc(){
  load_1="load_data"
  load_2="concurrent_load"
  current_ip=`ip a | grep -Eo "([0-9]{1,3}\.){3}[0-9]{1,3}" | grep -v "127.0.0.1" | grep -Ev "([0-9]{1,3}\.){3}255" | head -n 1`
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
  current_ip=`ip a | grep -Eo "([0-9]{1,3}\.){3}[0-9]{1,3}" | grep -v "127.0.0.1" | grep -Ev "([0-9]{1,3}\.){3}255" | head -n 1`
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
  run_tpch
  #  echo "start load data ---> small"
  #  load_data_op small
  #  echo "start load data ---> large"
  #  # large
  #  load_data_op large
  #  echo "finished load data"
  #
  #  echo "start concurrent load ---> small"
  #  # small
  #  concurrent_load_op small
  #  echo "start concurrent load ---> large"
  #  # large
  #  concurrent_load_op large
  #  echo "finished concurrent load"
}

main
