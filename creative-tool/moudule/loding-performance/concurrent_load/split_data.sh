#!/bin/bash

cwd=$(cd `dirname $0` && pwd)
cd $cwd
source $cwd/INPUT
log_file=$1
# mkdir data path
if [[ "${LDBC_FILE_SIZE}" == "small" ]]; then
    data_path=$DATA_PATH/sf${DATA_SIZE}/csv/bi/composite-projected-fk/initial_snapshot
else
    data_path=$DATA_PATH/social_network-csv_composite-sf${DATA_SIZE}
fi
echo "create $data_path on all nodes" | tee -a $log_file
grun all "mkdir -p $data_path/dynamic" > /dev/null
current_nodes=$( gssh | grep -c HostName)

split_dynamic_data_for_small_files() {
    all_folders=$(ls $data_path/dynamic/)
    for folder in $all_folders; do
        tmp_arr=()
        grun all "mkdir -p $data_path/dynamic/$folder"
        for i in $(seq $current_nodes); do
            if [[ $i == 1 ]]; then
                continue
            fi
            d=$((i%current_nodes))
            tmp_arr[$i]=$(ls $data_path/dynamic/$folder | awk "NR%${current_nodes}==$d")
        done
        for i in $(seq $current_nodes); do
            if [[ $i == 1 ]]; then
                continue
            fi
            mkdir -p $data_path/dynamic/$folder/m$i
            for file in ${tmp_arr[$i]}; do
                mv $data_path/dynamic/$folder/$file $data_path/dynamic/$folder/m$i/
            done
            gscp m$i "$data_path/dynamic/$folder/m$i" "$data_path/dynamic/$folder" > /dev/null
            grun m$i "cd $data_path/dynamic/$folder/ && mv m$i/*.csv ./ && rm -rf m$i"
            rm -rf $data_path/dynamic/$folder/m$i
        done
    done
}

split_file(){
    local lines=$(cat $1 | wc -l)
    split -l $((lines/current_nodes+1)) $1 -d -a 2 $2
}

split_dynamic_data_for_large_files() {
    cd $data_path/dynamic
    files=$(ls *.csv)
    for file in $files; do
        name=$(echo $file | sed "s/_0_0\.csv//")
        split_file $file ${name}
        rm $file
        mv ${name}00 $file
        for i in $(seq $current_nodes); do
            j=$((i-1))
            choose_file=${name}0${j}
            if [[ $j == 0 ]]; then
                continue
            elif [[ $j -ge 10 ]]; then
                choose_file=${name}${j}
            fi
            gscp m$i ./${choose_file} $data_path/dynamic/
            grun m$i "cd $data_path/dynamic && mv ${choose_file} ${file}"
            rm $data_path/dynamic/${choose_file}
        done
    done
}

if [[ "${LDBC_FILE_SIZE}" == "small" ]]; then
    split_dynamic_data_for_small_files
    grun all "rm -rf $data_path/*/*/_SUCCESS" > /dev/null
else
    split_dynamic_data_for_large_files
fi

grun all "ls $data_path/dynamic" | tee -a $log_file
grun all "ls $data_path/static" | tee -a $log_file
