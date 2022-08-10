#!/bin/bash

cwd=$(cd `dirname $0` && pwd)
cd $cwd
RESULT_DIR="/tmp/lp_rst"
mkdir -p ${RESULT_DIR}

#load_data_small(){
#  gsql CLEAR GRAPH STORE -HARD
#  echo "DATA_SET=ldbc_new" >> ${cwd}/load_data/INPUT
#
#  # test vertex
#  cd ${cwd}/load_data;bash main_script.sh
#  cat ${cwd}/load_data/RESULT >> ${RESULT_DIR}/small_vertex.rst
#  echo '' > ${cwd}/load_data/RESULT
#
#  # test edge
#  sed -i -e "s|DATA_PATH=.*|DATA_PATH=/home/tigergraph/load_data|g" ${cwd}/load_data/INPUT
#  sed -i -e "s|TEST_TYPE=.*|TEST_TYPE=edge|g" ${cwd}/load_data/INPUT
#  gsql CLEAR GRAPH STORE -HARD
#  cd ${cwd}/load_data;bash main_script.sh
#  cat ${cwd}/load_data/RESULT >> ${RESULT_DIR}/small_edge.rst
#  echo '' > ${cwd}/load_data/RESULT
#}
#
#
#load_data_large(){
#  gsql CLEAR GRAPH STORE -HARD
#  sed -i -e "s/LDBC_FILE_SIZE=.*/LDBC_FILE_SIZE=large/g" ${cwd}/load_data/INPUT
#
#  # test vertex
#  sed -i -e "s|DATA_PATH=.*|DATA_PATH=|g" ${cwd}/load_data/INPUT
#  sed -i -e "s|TEST_TYPE=.*|TEST_TYPE=vertex|g" ${cwd}/load_data/INPUT
#  cd ${cwd}/load_data;bash main_script.sh
#  cat ${cwd}/load_data/RESULT >> ${RESULT_DIR}/large_vertex.rst
#  echo '' > ${cwd}/load_data/RESULT
#
#  # test edge
#  sed -i -e "s|DATA_PATH=.*|DATA_PATH=/home/tigergraph/load_data|g" ${cwd}/load_data/INPUT
#  sed -i -e "s|TEST_TYPE=.*|TEST_TYPE=edge|g" ${cwd}/load_data/INPUT
#  gsql CLEAR GRAPH STORE -HARD
#  cd ${cwd}/load_data;bash main_script.sh
#  cat ${cwd}/load_data/RESULT >> ${RESULT_DIR}/large_edge.rst
#  echo '' > ${cwd}/load_data/RESULT
#
#}


load_data_op(){
  file_size=$1

  sed -i -e "s/LDBC_FILE_SIZE=.*/LDBC_FILE_SIZE=${file_size}/g" ${cwd}/load_data/INPUT

  # test vertex
  sed -i -e "s|DATA_PATH=.*|DATA_PATH=|g" ${cwd}/load_data/INPUT
  sed -i -e "s|TEST_TYPE=.*|TEST_TYPE=vertex|g" ${cwd}/load_data/INPUT
  gsql CLEAR GRAPH STORE -HARD
  cd ${cwd}/load_data;bash main_script.sh
  cat ${cwd}/load_data/RESULT >> ${RESULT_DIR}/load_data/${file_size}_vertex.rst
  echo '' > ${cwd}/load_data/RESULT

  # test edge
  sed -i -e "s|DATA_PATH=.*|DATA_PATH=/home/tigergraph/load_data|g" ${cwd}/load_data/INPUT
  sed -i -e "s|TEST_TYPE=.*|TEST_TYPE=edge|g" ${cwd}/load_data/INPUT
  gsql CLEAR GRAPH STORE -HARD
  cd ${cwd}/load_data;bash main_script.sh
  cat ${cwd}/load_data/RESULT >> ${RESULT_DIR}/load_data/${file_size}_edge.rst
  echo '' > ${cwd}/load_data/RESULT

}


concurrent_load_op(){
  file_size=$1

  sed -i -e "s/LDBC_FILE_SIZE=.*/LDBC_FILE_SIZE=${file_size}/g" ${cwd}/concurrent_load/INPUT

  # test vertex
  sed -i -e "s|DATA_PATH=.*|DATA_PATH=|g" ${cwd}/concurrent_load/INPUT
  sed -i -e "s|TEST_TYPE=.*|TEST_TYPE=vertex|g" ${cwd}/concurrent_load/INPUT
  gsql CLEAR GRAPH STORE -HARD
  cd ${cwd}/concurrent_load;bash main_script.sh
  cat ${cwd}/load_data/RESULT >> ${RESULT_DIR}/concurrent_load/${file_size}_vertex.rst
  echo '' > ${cwd}/load_data/RESULT

  # test edge
  sed -i -e "s|DATA_PATH=.*|DATA_PATH=/home/tigergraph/load_data|g" ${cwd}/concurrent_load/INPUT
  sed -i -e "s|TEST_TYPE=.*|TEST_TYPE=edge|g" ${cwd}/concurrent_load/INPUT
  gsql CLEAR GRAPH STORE -HARD
  cd ${cwd}/concurrent_load;bash main_script.sh
  cat ${cwd}/load_data/RESULT >> ${RESULT_DIR}/concurrent_load/${file_size}_edge.rst
  echo '' > ${cwd}/load_data/RESULT

}


main(){
  echo "start load data ---> small" >> ${RESULT_DIR}/sum.rst
  # small
  load_data_op small
  echo "start load data ---> large" >> ${RESULT_DIR}/sum.rst
  # large
  load_data_op large
  echo "finished load data" >> ${RESULT_DIR}/sum.rst

#  echo "start concurrent load ---> small" >> ${RESULT_DIR}/sum.rst
#  # small
#  concurrent_load_op small
#  echo "start concurrent load ---> large" >> ${RESULT_DIR}/sum.rst
#  # large
#  concurrent_load_op large
#  echo "finished concurrent load" >> ${RESULT_DIR}/sum.rst
}