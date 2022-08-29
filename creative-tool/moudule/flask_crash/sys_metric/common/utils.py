# coding=utf-8
import datetime
import json
import logging
import os
import socket
import time
import requests
from bs4 import BeautifulSoup
import jenkins
import hashlib
import paramiko
from paramiko.ssh_exception import NoValidConnectionsError, AuthenticationException
from long_running.common import const

RECURSIVE_CREATE_DIR = lambda dp: os.makedirs(dp) or dp if not os.path.exists(dp) else dp  # ---> mkdir -p


class JenkinsDemo:
    def __init__(self, ip, port, username, password):
        self.ip = ip
        self.port = port
        self.username = username
        self.password = password
        self.entity = self.__init_entity()

    def __get_job_id_from_queue_id(self, queue_id):
        logging.info("queue_id is :%s" % queue_id)
        # wait queue to get job id
        while True:
            queue_info = self.entity.get_queue_item(queue_id)
            if queue_info and queue_info.get('executable'):
                job_id = queue_info.get('executable').get('number')
                return job_id
            else:
                logging.debug("waiting for queue_id(%s) response" % queue_id)
                time.sleep(1)

    def __job_build(self, job_param, job_name):
        jk_queue_id = self.entity.build_job(job_name, job_param)
        jk_job_id = self.__get_job_id_from_queue_id(jk_queue_id)
        return jk_job_id

    def __init_entity(self):
        return jenkins.Jenkins('http://{ip}:{port}'.format(ip=self.ip, port=self.port),
                               username=self.username,
                               password=self.password)

    def run(self, job_param, job_name):

        if job_name:
            job_id = self.__job_build(job_param, job_name)
            logging.info("Create a new task successfully,job id:{}".format(job_id))
            return job_id
        else:
            logging.info("Jenkins job name error")

    def get(self, job_id, job_name, get_type=None):
        """
        if get_type:
            return all info
        else:
            return
        job status : 1.SUCCESS, 2.FAILURE, 3.ABORTED, 4.None -> RUNNING

        :param job_id:
        :param job_name:
        :param get_type:
        :return:
        """
        return_result = self.entity.get_build_info(name=job_name, number=job_id)
        if get_type:
            filter_result = return_result.get(get_type)
            if filter_result:
                return filter_result
            else:
                # raise Exception("Data not exist!")
                return False
        else:
            return return_result


class SSHRemoteCall(object):
    def __init__(self, hostname, port, user, password=None, key_file_path=None):
        self.hostname = hostname
        self.port = port
        self.user = user
        self.password = password
        self.key_file_path = key_file_path

    def __run_cmd_with_password(self, run_cmd):
        client = paramiko.SSHClient()
        client.set_missing_host_key_policy(paramiko.AutoAddPolicy())

        try:

            client.connect(hostname=self.hostname,
                           port=self.port,
                           username=self.user,
                           password=self.password)

            print("connecting:%s......." % self.hostname)
            stdin, stdout, stderr = client.exec_command(run_cmd)
        except NoValidConnectionsError as e:
            print("connect error")
        except AuthenticationException as e:
            print("password error")
        else:
            result_out = stdout.read().decode('utf-8')
            result_err = stderr.read().decode('utf-8')
            if result_err:
                return "error: {}".format(result_err)
            else:
                return result_out
        finally:
            client.close()

    def __do_cmd_with_rsa_key(self, run_cmd):
        print(run_cmd)
        client = paramiko.SSHClient()
        private_key = paramiko.RSAKey.from_private_key_file(self.key_file_path)
        client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
        try:
            client.connect(hostname=self.hostname,
                           port=self.port,
                           username=self.user,
                           pkey=private_key
                           )
            print("connecting:%s......." % self.hostname)
            stdin, stdout, stderr = client.exec_command(run_cmd)
        except NoValidConnectionsError as e:
            print("connect error")
        except AuthenticationException as e:
            print("password error")
        else:
            result_out = stdout.read().decode('utf-8')
            result_err = stderr.read().decode('utf-8')
            if result_err:
                return "error: {}".format(result_err)
            else:
                return result_out
        finally:
            client.close()

    def run(self, run_cmd):
        if self.password:
            return self.__run_cmd_with_password(run_cmd)
        elif self.key_file_path:
            return self.__do_cmd_with_rsa_key(run_cmd)
        else:
            raise Exception("password and key file -> None")


def get_now():
    datetime_format = "%Y-%m-%d-%H:%M:%S"
    now_time = datetime.datetime.now()
    return now_time.strftime(datetime_format)


def get_jenkins_config(machine_num):
    with open("etc/jenkins_config.json", "r+") as json_file:
        rst_config = json.load(json_file)
        json_file.close()
        return rst_config["machine_{}".format(machine_num)]


def get_pkg_url_from_version(version, url_type="http", pgk_type="hourly",
                             download_url="http://192.168.99.101/download.html"):
    web_data = requests.get(download_url)
    soup = BeautifulSoup(web_data.text, 'lxml')
    filter_list = [version, url_type, pgk_type]
    tag_a_list = soup.find_all("a")
    pkg_url_list = [single_url["href"] for single_url in tag_a_list if
                    False not in [single_filter in single_url["href"] for single_filter in filter_list]]

    return pkg_url_list


def get_machine_private_ip(src_ip, machine_num=1):
    """

    :param src_ip:
    :param get_ip_type:  0 ---> public ip, 1---> private ip
    :param machine_num:
    :return:
    """
    common_path = os.path.dirname(os.path.abspath(__file__))
    single_host = SSHRemoteCall(src_ip, 22, "graphsql", key_file_path="{}/etc/qe_ec2.pem".format(common_path))
    #
    cmd = "gssh |grep '#cluster.nodes:'"
    rst = single_host.run('sudo su - tigergraph -c "{}"'.format(cmd))
    machine_list = rst.split(': ', 1)[1].split(",")
    if machine_num > len(machine_list) or machine_num <= 0:
        raise Exception("machine number no exist!")
    else:
        return machine_list[machine_num - 1].split(":")[1]


def get_machine_private_ip_one(src_ip):
    """
    :param src_ip:
    :return:
    """
    common_path = os.path.dirname(os.path.abspath(__file__))
    print(common_path)
    single_host = SSHRemoteCall(src_ip, 22, "graphsql", key_file_path="{}/etc/qe_ec2.pem".format(common_path))
    cmd = 'ip a | grep -Eo "([0-9]{1,3}\.){3}[0-9]{1,3}" | grep -v "127.0.0.1" | grep -Ev "([0-9]{1,3}\.){3}255" | head -n 1'
    rst = single_host.run(cmd)
    return rst


def test():
    print("test11111111")


def app_message_notification(title, msg):
    url = "https://api.day.app/snLJigKpYsLuzFBZ4waHcb/{}/{}".format(title, msg)
    requests.get(url)


def init_dir():
    dir_list = ["/tmp/bisect/build", "/tmp/bisect/result", "/tmp/bisect/log", "/tmp/bisect/build/app"]
    try:
        for dir_path in dir_list:
            logging.info("start creating dir:{}".format(dir_path))
            RECURSIVE_CREATE_DIR(dir_path)
    except Exception as e:
        logging.error("can't creat dir,reason:{}".format(e))


def save_gpe_crash_log(src_ip, keyword_targeting=None):
    single_host = SSHRemoteCall(src_ip, 22, "graphsql", key_file_path="etc/qe_ec2.pem")

    get_log_cmd = 'sudo su - tigergraph -c \'grun all  "tail -n50 /home/tigergraph/tigergraph/log/gpe/log.INFO|grep \\"Crashed with stacktrace\\" -A 50|grep \\"End of stacktrace\\" -B 50"\''

    rst = single_host.run(get_log_cmd)
    now_date = get_now()
    crash_result_dir = "/tmp/bisect/log/result/gpe_crash"
    RECURSIVE_CREATE_DIR("{}/{}".format(crash_result_dir, src_ip))

    with open("{}/{}/{}.log".format(crash_result_dir, src_ip, now_date), "w+") as crash_f:
        crash_f.write(rst)
        crash_f.close()

    if keyword_targeting and (keyword_targeting in rst):
        msg = "Find the specified issue({}) in ip:{}".format(keyword_targeting, src_ip)
        logging.info(msg)
        with open('{}/specified_result.log'.format(crash_result_dir), "a+") as rst_f:
            rst_f.write(msg)
            rst_f.close()
    else:
        msg = "Find Normal issue in ip:{}".format(src_ip)
        logging.info(msg)
    # send message to phone notification
    app_message_notification(keyword_targeting, msg)


def check_cluster_service_status(src_ip, specified_server=None):
    single_host = SSHRemoteCall(src_ip, 22, "graphsql", key_file_path="etc/qe_ec2.pem")
    if specified_server:
        get_log_cmd = 'sudo su - tigergraph -c \'gadmin status -v |grep "{}"|grep "Down" \''.format(
            specified_server.upper())
    else:
        get_log_cmd = 'sudo su - tigergraph -c \'gadmin status -v |grep "Down" \''

    run_rst = single_host.run(get_log_cmd) or "None"
    return_rst = {
        "status": False if "Down" in run_rst else True,
        "data": run_rst or None
    }

    return return_rst


def start_cluster_service(src_ip, server_name=None):
    single_host = SSHRemoteCall(src_ip, 22, "graphsql", key_file_path="etc/qe_ec2.pem")
    if server_name:
        get_log_cmd = 'sudo su - tigergraph -c \'gadmin start {} \''.format(server_name.upper())
    else:
        get_log_cmd = 'sudo su - tigergraph -c \'gadmin start all \''
    while True:
        run_rst = single_host.run(get_log_cmd)
        logging.info(run_rst)
        re_check_rst = check_cluster_service_status(src_ip)
        if re_check_rst.get("status"):
            return True
        else:
            logging.info("start {} server failed,retry".format(src_ip))
            continue


def cluster_run_cmd(src_ip, run_cmd):
    single_host = SSHRemoteCall(src_ip, 22, "graphsql", key_file_path="etc/qe_ec2.pem")
    user_cmd = 'sudo su - tigergraph -c \'{} \''.format(run_cmd)
    run_rst = single_host.run(user_cmd)
    logging.info("{} run_cmd :{} ---result:\n{}".format(src_ip, user_cmd, run_rst))


def get_machine_crash_result(src_ip, crash_type, return_format="map", specified_pwd=None):
    """
    :param specified_pwd:
    :param return_format:
    :param format:
    :param crash_type:
    :param src_ip:

    :return:
    """
    common_path = os.path.dirname(os.path.abspath(__file__))
    if not specified_pwd:
        single_host = SSHRemoteCall(src_ip, 22, "graphsql", key_file_path="{}/etc/qe_ec2.pem".format(common_path))
    else:
        single_host = SSHRemoteCall(src_ip, 22, specified_pwd.get("user"), password=specified_pwd.get("password"))
    #
    cmd = "cat {}".format(os.path.join(const.INSTANCE_CRASH_RESULT_DIR, f"{crash_type}.json"))
    rst = single_host.run(cmd)
    if (not rst) or ("No such file or directory" in rst):
        return False
    else:
        if (return_format == "map") and (rst is not None):
            return json.loads(rst)

        else:
            return rst


def calculate_string_md5(input_string):
    """
    description:
    :param input_string:md5
    :return:  eg: 098F6BCD4621D373CADE4E832627B4F6

    """
    md5 = hashlib.md5()
    b = input_string.encode(encoding='utf-8')
    md5.update(b)
    str_md5 = md5.hexdigest()
    return str_md5


def test_ip_port_reachable(ip, port):
    """
    description: test connectivity
    """
    status = True
    timeout = socket.getdefaulttimeout()
    socket.setdefaulttimeout(1)
    s = socket.socket()
    try:
        s.connect((ip, port))
    except socket.error:
        status &= False
    finally:
        s.close()
        socket.setdefaulttimeout(timeout)
    return status
