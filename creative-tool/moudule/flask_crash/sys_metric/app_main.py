# coding=utf-8
import logging
import os
import sys

from flask import jsonify

sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from sys_metric.trigger.flask_trigger import FlaskServer
# from sys_metric.trigger.flask_trigger import start_instance_scheduler
from sys_metric.trigger.flask_trigger import set_environment
from sys_metric.common import log

if __name__ == '__main__':
    # log.Logger(log_name="")  # 生成一个全局的root logger,使用logging.info等来输出信息
    # 定时更新instance信息
    set_environment()
    # start_instance_scheduler(600)

    FlaskServer().run_server()
    

