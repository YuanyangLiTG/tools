# coding:utf-8
import random
import sys

# need to replace by shell script
BLADE_PATH = "/tmp/chaosblade"
TG_PATH = "/home/tigergraph/tigergraph/"
CPU_CORE_COUNT = 1
NODE_COUNT = 6
NETCARD = "eth0"
SUDO_PERMISSION = "false"

# experiment timeout
EXP_DURATION = 300  # seconds
PROCESS_STOP_DURATION = 90  # seconds
NETWORK_DELAY_DURATION = 30  # seconds

# experiment count once
EXP_COUNT = 3


def select_exp_nodes(exp_name, process=""):
    node_list = []
    for i in range(NODE_COUNT):
        node_list.append("m%d" % (i + 1))
    if exp_name in ["cpu_load", "mem_load", "disk_burn", "network_delay", "disk_fill"]:
        count = random.randint(1, NODE_COUNT)
        random.shuffle(node_list)
        return node_list[:count]
    elif exp_name in ["process_kill", "process_stop"]:
        if process in ['tg_dbs_gsed', 'tg_dbs_gped']:
            half = int(NODE_COUNT / 2)
            select_nodes = []
            for i in range(max(1, int(NODE_COUNT / 2))):
                select = random.choice([0, node_list[i], node_list[i + half]])
                if select:
                    select_nodes.append(select)
            return select_nodes
        else:
            max_count = min(5, NODE_COUNT) - 1
            random.shuffle(node_list)
            return node_list[:max_count]


def create_exp_command(exps, exclude=[]):
    exps = exps.split(",")
    if SUDO_PERMISSION == "false" and "network_delay" in exps:
        exps.remove("network_delay")
    exps = list(set(exps) - set(exclude))
    exp = random.choice(exps)
    command = ""
    process = ""
    if exp == "cpu_load":
        percents = [90, 95, 100]
        command = "c cpu load --cpu-count %s --cpu-percent %s --timeout %s" % (
        CPU_CORE_COUNT, random.choice(percents), EXP_DURATION)
    elif exp == "mem_load":
        percents = [90, 95, 100]
        command = "c mem load --mode ram --mem-percent %s --timeout %s" % (random.choice(percents), EXP_DURATION)
    elif exp == "disk_burn":
        read_or_write = ["read", "write"]
        command = "c disk burn --%s --path %s --timeout %s" % (random.choice(read_or_write), TG_PATH, EXP_DURATION)
    elif exp == "disk_fill":
        percents = [90, 95, 100]
        command = "c disk fill --path %s --percent %s --timeout %s" % (TG_PATH, random.choice(percents), EXP_DURATION)
    elif exp == "process_stop":
        process_list = ["tg_dbs_gsed", "tg_dbs_restd", "tg_dbs_gped", "tmp_tg_dbs_gsqld", "kafka.Kafka", "Dzookeeper"]
        process = random.choice(process_list)
        command = "c process stop --process %s --timeout %s" % (process, random.randint(10, PROCESS_STOP_DURATION))
    elif exp == "process_kill":
        process_list = ["tg_dbs_gsed", "tg_dbs_restd", "tg_dbs_gped", "tmp_tg_dbs_gsqld", "kafka.Kafka", "Dzookeeper",
                        "etcd"]
        process = random.choice(process_list)
        command = "c process kill --process %s --timeout %s" % (process, PROCESS_STOP_DURATION)
    elif exp == "network_delay":
        times = [500, 1000, 1500, 2000]
        ports = [9000, 9188, 19999, 30002, 20000]
        command = "c network delay --interface %s --time %s --offset 1 --local-port %s" % (
        NETCARD, random.choice(times), random.choice(ports))
    elif exp == "service_restart":
        services = ['gpe', 'gse', 'gsql', 'restpp', 'kafka', 'zk']
        command = "gadmin restart %s -y" % (random.choice(services))

    if exp == "service_restart":
        result = command
    else:
        node_list = select_exp_nodes(exp, process)
        result = ""
        for node in node_list:
            if int(node.replace("m", "")) > 5 and "gsqld" in exp:
                continue
            result += 'grun %s "%s/blade %s"\n' % (node, BLADE_PATH, command)
    return result, exp


def final_command(exps):
    exclude_list = []
    for i in range(int(EXP_COUNT)):
        exp_command, exp_kind = create_exp_command(exps, exclude=exclude_list)
        exclude_list.append(exp_kind)
        if "process" in exp_kind or exp_kind == "service_restart":
            exclude_list.extend(["process_stop", "process_kill", "service_restart"])
        if exp_kind == "service_restart":
            print(exp_command)
        else:
            print(exp_command[:-1])


if __name__ == "__main__":
    exps = sys.argv[1]
    final_command(exps)
