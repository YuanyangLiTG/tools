# coding=utf-8

flask_server_ip = "0.0.0.0"
flask_server_port = 8002
MONGODB_DATABASE = "long_running"
MONGODB_IP = "192.168.50.50"
MONGODB_PORT = "27017"
INSTANCE_SRC_URL = "http://192.168.50.165:8123/user_instances"
INSTANCE_CRASH_RESULT_DIR = "/tmp/crash_result"
GET_INSTANCE_INFO_MODEL = 2  # 1为缓存模式, 2为源数据模式
GET_CRASH_INFO_MODEL = 2   # 1为缓存模式, 2为源数据模式
IGNORE_API_PRINT = {
    "api": []
}
