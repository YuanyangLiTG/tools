# coding=utf-8
import json
import logging
import os
import subprocess

LOG_DIR_PATH = "/home/tigergraph/tigergraph/log"
KNOW_CRASH_FILE_PATH = r"/moudule/flask_crash/crash_test/data"


def init_sum_dir_and_file(crash_type):
    os.makedirs(KNOW_CRASH_FILE_PATH, exist_ok=True)
    with open(os.path.join(KNOW_CRASH_FILE_PATH, "{}.json".format(crash_type)), "w+") as f:
        f.write("[]")


# def start_scheduler(time_sec, func_addr, scheduler_id, kwargs):
#     """
#
#     :param kwargs:
#     :param scheduler_id:
#     :param func_addr:
#     :param time_sec:
#     :return:
#     """
#     scheduler = BackgroundScheduler()
#     scheduler.add_job(func_addr, 'interval', seconds=time_sec, id=scheduler_id, kwargs=kwargs)
#     scheduler.start()


def run_shell(cmd):
    rst_code, rst_msg = subprocess.getstatusoutput(
        "export PATH=/home/tigergraph/tigergraph/app/cmd:$PATH;{}".format(cmd))
    if rst_code == 0:
        return rst_msg
    else:
        subprocess.getstatusoutput("echo  {}  >> /tmp/error_cmd.log".format(cmd))
        print("shell cmd run failed and error code is : {},detail:{}".format(rst_code, rst_msg))
        raise RuntimeError("shell cmd run failed and error code is : {},detail:{}".format(rst_code, rst_msg))


def find_file(search_path, include_str=None, filter_strs=None):
    """
    查找指定目录下所有的文件（不包含以__开头和结尾的文件）或指定格式的文件，若不同目录存在相同文件名，只返回第1个文件的路径
    :param search_path: 查找的目录路径
    :param include_str: 获取包含字符串的名称
    :param filter_strs: 过滤包含字符串的名称
    """
    if filter_strs is None:
        filter_strs = []

    files = []
    # 获取路径下所有文件
    names = os.listdir(search_path)
    for name in names:
        path = os.path.abspath(os.path.join(search_path, name))
        if os.path.isfile(path):
            # 如果不包含指定字符串则
            if include_str is not None and include_str not in name:
                continue

            # 如果未break，说明不包含filter_strs中的字符
            for filter_str in filter_strs:
                if filter_str in name:
                    break
            else:
                files.append(path)
        else:
            files += find_file(path, include_str=include_str, filter_strs=filter_strs)
    return files


def get_machine_count():
    get_machine_count_cmd = "gssh | grep '#cluster.nodes' | awk -F ',' '{print NF}'"
    cmd_rst = run_shell(get_machine_count_cmd)
    machine_count = int(cmd_rst.strip())
    return machine_count


def get_crash_info(crash_type, crash_file_name, machine_name):
    crash_dir = os.path.join(LOG_DIR_PATH, crash_type)
    print("Get crash info path:{}".format(crash_dir))
    get_log_cmd = 'grun {} "tail -n200 {}|grep \\"End of stacktrace\\" -B 50|grep \\"stacktrace\\" -A 50"|grep -v "### Connecting to" ' \
        .format(machine_name,
                os.path.join(crash_dir, crash_file_name))
    cmd_rst = run_shell(get_log_cmd)
    if cmd_rst:
        return cmd_rst
    else:
        return False


def get_log_file_list(log_type, machine_name):
    get_log_file_cmd = "grun {} \"ls -tr {} |grep -v 'log'\"|grep INFO" \
        .format(machine_name,
                os.path.join(LOG_DIR_PATH, log_type.lower()))

    cmd_rst = run_shell(get_log_file_cmd)
    file_list = cmd_rst.strip().split("\n")
    return file_list


def assemble_crash_info_to_list(crash_str):
    split_info_list = crash_str.split('\n')
    stacktrace_list = list()
    for i in split_info_list:
        if i and "#" in i:  # ignore "Crashed with stacktrace" and "End of stacktrace"
            flag = i.split("# ")[-1]
            if flag.startswith(
                    "0x"):  # eg: 1# 0x00007F325331A630 in /home/tigergraph/tigergraph/app/3.7.0/.syspre/usr/lib_ld1/libpthread.so.0
                stacktrace_list.append(i.split(" in ")[-1])
            else:
                stacktrace_list.append(flag)

    return stacktrace_list


def extract_crash_info(src_data):
    data_list = src_data.split("\n")
    add_status = 0
    crash_list = list()
    tmp_save_crash = ""
    for single_line in data_list:

        if add_status == 1 and "End of" not in single_line:
            tmp_save_crash += single_line
            tmp_save_crash += '\n'
        if "stacktrace" in single_line and "End of" not in single_line:
            add_status = 1
            tmp_save_crash = ""
        elif "End of stacktrace" in single_line:
            crash_list.append(tmp_save_crash.strip())
            add_status = 0
        else:
            continue

    return crash_list


def crash_compare(new_crash_map, crash_type):
    """

    :param crash_type:
    :param new_crash_map: {
                    "path":"/home/tigergraph/tigergraph/log/gpe/INFO.20220623-174016.25063",
                    "data":"E0625 20:37:49.558868   385 glogging.cpp:132] ============ Crashed with stacktrace ============ ....",
                    "machine":"m1"
    }
    :return:
    """
    print("----------crash_compare-----------")
    print(new_crash_map)
    # 如果当前文件没有crash信息则跳过
    if not new_crash_map or isinstance(new_crash_map.get("data"), bool):
        return False

    # 如果有crash信息则需要与已知的crash比对
    crash_str = new_crash_map.get("data")
    with open(os.path.join(KNOW_CRASH_FILE_PATH, "{}.json".format(crash_type)), "r+") as f_r:
        file_data = f_r.read()
        known_crash_list = json.loads(file_data) if file_data else []

    print("Find crash count: {}".format(crash_str.count("End of stacktrace")))

    rst_list = extract_crash_info(crash_str)
    current_crash_list = list()
    for crash in rst_list:
        if "#" in crash:
            crash_list_data = assemble_crash_info_to_list(crash)
            current_crash_list.append({
                "path": new_crash_map.get("path"),
                "machine": new_crash_map.get("machine"),
                "data": crash,
                "list_data": crash_list_data
            })
    current_crash_list = crash_list_remove_duplicates(current_crash_list)
    new_crash_list = list()
    if known_crash_list:
        for current_crash in current_crash_list:
            flag = 0  # 0 -> New issue , 1 -> Known issue

            for known_crash in known_crash_list:
                if current_crash.get("list_data") == assemble_crash_info_to_list(known_crash.get("data")):
                    flag = 1

                    break
                else:
                    continue
            if flag == 0:
                print("New issue")
                new_crash_list.append(current_crash)
            else:
                print("Known issue")
    else:
        new_crash_list = current_crash_list
    print("+++++++crash length:{}".format(len(new_crash_list)))
    sum_crash_list = known_crash_list + new_crash_list
    with open(os.path.join(KNOW_CRASH_FILE_PATH, "{}.json".format(crash_type)), "w+") as f_w:
        f_w.write(json.dumps(sum_crash_list))
    return True

def crash_list_remove_duplicates(crash_list):
    tmp_list = list()
    for new_crash in crash_list:
        if len(tmp_list) <1:
            tmp_list.append(new_crash)
        else:
            for know_crash in tmp_list:
                if new_crash.get("list_data") == know_crash.get("list_data"):
                    continue
                else:
                    tmp_list.append(new_crash)
    return tmp_list

with open("data/info.log", "r+") as f:
    get_data = f.read()

data_1 = {
    "path": "/home/tigergraph/tigergraph/log/gpe/INFO.20220623-174016.25063",
    "data": get_data,
    "machine": "m1"
}
crash_compare(data_1, "gpe")
