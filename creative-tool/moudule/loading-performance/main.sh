#!/bin/bash
cwd=$(cd $(dirname $0) && pwd)
cd $cwd
source ./INPUT

run_main(){

  bash ${cwd}/prepare.sh
  sudo su - $USER_NAME -c "bash ${cwd}/run.sh"

}
run_main