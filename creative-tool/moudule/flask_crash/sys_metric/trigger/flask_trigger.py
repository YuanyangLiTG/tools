# coding=utf-8
import logging

import better_exceptions
from flask import Flask, render_template
from flask_cors import CORS

from sys_metric.common import const as common_const
from sys_metric.trigger.flask_blueprint.crash.views_api import crash_api_bp
from sys_metric.model.data_flow.request_data import BeforeRequest, AfterRequest


# from sys_metric.model.data_flow.mongodb import MongoDB
# from sys_metric.model.scheduler import instance


class FlaskServer:
    """
    flask服务端
    """

    def __init__(self):
        self.flask_ip = common_const.flask_server_ip
        self.flask_port = common_const.flask_server_port
        logging.info("flask server is started on:{}:{}".format(self.flask_ip, self.flask_port))

    def run_server(self):
        app = Flask(__name__, template_folder="templates", static_folder="static")
        CORS(app, supports_credentials=True)

        # 主页面
        @app.route('/')
        def index():
            rst = app.url_map
            print(rst)
            return render_template("index.html")

        #
        @app.before_request
        def before_request():
            """
            这个钩子会在每次客户端访问视图的时候执行
            """

        @app.after_request
        def after_request(response):
            # 必须返回response参数
            AfterRequest.test()
            AfterRequest.show(response)
            return response

        # 注册子页面蓝图
        self.register_all_blueprint(app)

        # 运行服务
        app.run(host=self.flask_ip, port=self.flask_port)

    def register_all_blueprint(self, app):
        app.register_blueprint(crash_api_bp)


# def start_instance_scheduler(time_sec):
#     """
#     定时器去更新instance缓存信息
#     :param time_sec: 定时器时间间隔
#     :return:
#     """
#     scheduler = BackgroundScheduler()
#     scheduler.add_job(instance.update_instance_info, 'interval', seconds=time_sec, id="get_instance")
#     scheduler.start()


def set_environment():
    better_exceptions.MAX_LENGTH = None
    better_exceptions.hook()
