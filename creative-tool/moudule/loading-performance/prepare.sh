#!/bin/bash

cwd=$(cd $(dirname $0) && pwd)
cd $cwd
source ./INPUT


cp_dir(){
  echo "Step ---> copy load_data dir"
  sudo cp -rf ${cwd}/load_data ${TEST_MODULE_DIR}
  sudo chmod -R 777 ${TEST_MODULE_DIR}/load_data
  echo "Step ---> copy concurrent_load dir"
  sudo cp -rf ${cwd}/concurrent_load ${TEST_MODULE_DIR}
  sudo chmod -R 777 ${TEST_MODULE_DIR}/concurrent_load
}

install_udf(){
  # install udf
  sudo su - $USER_NAME -c "bash ${TEST_MODULE_DIR}/put_exprfunction/main_script.sh"

}

main(){
  chmod -R 777 ./*
  cp_dir
  install_udf
}
main