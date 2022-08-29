import logging
import logging.config
import os


class Logger:
    # all_log_dir_path = r"G:\TigerGraph\bisect\lyy\tools\performance_script\temp_test\log"  # 所有日志存储目录路径

    all_log_dir_path = "/tmp/log"  # 所有日志存储目录路径

    def __init__(self, level=logging.DEBUG, log_name="default"):
        self.log_name = log_name
        self.current_logger_dir_path = os.path.join(Logger.all_log_dir_path, log_name or "global")  # 当前logger的目录路径
        os.makedirs(self.current_logger_dir_path, exist_ok=True)
        logging.config.dictConfig(self.get_log_setting())  # load 配置文件

        self.logger = logging.getLogger(log_name)
        self.logger.setLevel(level)

    def debug(self, message):
        self.logger.debug(message)

    def info(self, message):
        self.logger.info(message)

    def warn(self, message):
        self.logger.warning(message)

    def error(self, message):
        self.logger.error(message)

    def cri(self, message):
        self.logger.critical(message)

    def get_log_setting(self):
        setting_map = {
            'version': 1,  # 保留字
            'disable_existing_loggers': False,  # 禁用已经存在的logger实例,也就是如果为true且有两个logger只会保留最后一个
            # 过滤器
            'filters': {},
            # 日志文件的格式
            'formatters': {
                # 详细的日志格式
                'standard': {
                    'format': "[%(asctime)s][%(levelname)s][%(threadName)s:%(thread)d][task_id:%(name)s][%(filename)s:%(lineno)d] %(message)s"
                },
                # 简单的日志格式
                'simple': {
                    'format': '[%(asctime)s][%(levelname)s][%(threadName)s:%(thread)d] [%(filename)s:%(lineno)d] %(message)s'
                },
                # 定义一个特殊的日志格式
                'specific': {
                    'format': '[%(asctime)s][%(message)s]'
                }
            },

            # 处理器
            'handlers': {
                # 终端
                'console': {
                    'level': 'DEBUG',
                    'class': 'logging.StreamHandler',
                    'formatter': 'simple'
                },
                # INFO
                'info': {
                    'level': 'INFO',
                    'class': 'logging.handlers.RotatingFileHandler',  # 保存到文件，自动切
                    'filename': os.path.join(self.current_logger_dir_path,
                                             "{}_INFO.log".format(self.log_name or "global")),
                    'maxBytes': 1024 * 1024 * 50,  # 日志大小 50M
                    'backupCount': 5,  # 最多备份几个
                    'formatter': 'standard',
                    'encoding': 'utf-8',
                },
                # ERROR
                'error': {
                    'level': 'ERROR',
                    'class': 'logging.handlers.RotatingFileHandler',  # 保存到文件，自动切
                    'filename': os.path.join(self.current_logger_dir_path,
                                             "{}_ERROR.log".format(self.log_name or "global")),
                    'maxBytes': 1024 * 1024 * 50,  # 日志大小 50M
                    'backupCount': 5,
                    'formatter': 'standard',
                    'encoding': 'utf-8',
                },
                # DEBUG
                'debug': {
                    'level': 'DEBUG',
                    'class': 'logging.handlers.RotatingFileHandler',  # 保存到文件，自动切
                    'filename': os.path.join(self.current_logger_dir_path,
                                             "{}_DEBUG.log".format(self.log_name or "global")),
                    'maxBytes': 1024 * 1024 * 50,  # 日志大小 50M
                    'backupCount': 5,
                    'formatter': 'standard',
                    'encoding': "utf-8"
                }
            },
            'loggers': {
                # 默认的logger应用如下配置
                self.log_name: {
                    'handlers': ['console', 'info', 'error', 'debug'],
                    'level': 'DEBUG',
                    'propagate': True,  # 向不向更高级别的logger传递
                },

            },
        }
        return setting_map


logger_flask = Logger(log_name="flask")  # flask的日志对象

logger_tools = Logger(log_name="tools")  # tools的日志对象
