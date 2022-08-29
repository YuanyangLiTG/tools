# coding=utf-8
import pymongo
import logging
from long_running.common import const


class MongoDB:

    def __init__(self, db_name=const.MONGODB_DATABASE):
        """
        description: 初始化一个MongoDB数据库
        :param db_name: MongoDB数据库的名字
        """
        self.db_obj = self.init_connection()
        self.db_name = db_name

    def init_connection(self):
        """
        description: 初始化一个MongoDB的连接
        :return: MongoDB连接
        """
        db_client = pymongo.MongoClient("mongodb://{ip}:{port}/".format(
            ip=const.MONGODB_IP,
            port=const.MONGODB_PORT
        )
        )
        return db_client

    def insert_one(self, collection_name, insert_data):
        """
        description: 插入一个新数据(若数据存在则会抛异常)
        :param collection_name: 需要插入数据的集合
        :param insert_data: 需要插入的数据
        :return: 当前插入数据的MongoDB的_id, eg:6294cf352d5584a45c2f10ff
        """
        db_obj = self.db_obj[self.db_name]
        collection_obj = db_obj[collection_name]
        # 需要判断一下数据是否存在
        if collection_obj.count_documents({"identify": insert_data.get("identify")}) > 0:
            logging.info("数据已存在:{}".format(insert_data))
            return False
        else:
            return_obj = collection_obj.insert_one(insert_data)
            return str(return_obj.inserted_id)

    def update_one(self, query, update_data, collection_name):
        db_obj = self.db_obj[self.db_name]
        collection_obj = db_obj[collection_name]
        new_values = {"$set": update_data}

        collection_obj.update_one(query, new_values)
        return True

    def get_one(self, query, collection_name):
        db_obj = self.db_obj[self.db_name]
        collection_obj = db_obj[collection_name]
        rst = collection_obj.find(query)
        for i in rst:
            i.pop("_id")
            return i


    def get_all_with_query(self, query, collection_name):
        db_obj = self.db_obj[self.db_name]
        collection_obj = db_obj[collection_name]
        rst = collection_obj.find(query)
        rst_list = list()
        for i in rst:
            i.pop("_id")
            rst_list.append(i)
        return rst_list

    def get_all_without_query(self,collection_name):
        db_obj = self.db_obj[self.db_name]
        collection_obj = db_obj[collection_name]
        rst_list = list()
        for i in collection_obj.find():
            i.pop("_id")
            rst_list.append(i)
        return rst_list

    def delete_one(self, query, collection_name):
        db_obj = self.db_obj[self.db_name]
        collection_obj = db_obj[collection_name]
        rst = collection_obj.delete_one(query).deleted_count
        if int(rst) > 0:
            return True
        else:
            return False

