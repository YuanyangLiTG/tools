# coding = utf-8
import json
import logging
from flask import jsonify
from prettytable import PrettyTable
from long_running.common import const


class DataTrace:

    @classmethod
    def log_and_return(cls, return_msg=None, request=None):
        """

        """
        return_json_msg = {
            "code": 200,
            "status": "success",
            "data": return_msg
        }
        print(return_json_msg)
        # if request.path in const.IGNORE_API_PRINT["api"]:
        #     cls.show_request_message(request, "ignore")
        # else:
        #     cls.show_request_message(request, str(return_msg))
        return jsonify(return_json_msg)

    @classmethod
    def show_request_message(cls, request, return_msg=None):
        """

        +--------------+----------------+----------------------+
        | Message Type | Message Method |     Message API      |
        +--------------+----------------+----------------------+
        |   Request    |      GET       | /manage/service_info |
        +--------------+----------------+----------------------+


        """
        conn_tb = PrettyTable()
        request_info = ""
        if request.args.to_dict():
            request_info += "\nRequest Args:\n{}\n".format(request.args.to_dict())
        if request.json:
            request_info += "\nRequest Body:\n{}\n".format(request.json)
        if request.form.to_dict():
            request_info += "\nRequest Form:\n{}\n".format(request.form.to_dict())

        conn_tb.field_names = ["Message Type", "Message Method", "Message API"]
        conn_tb.add_row(["Request", request.method, request.path])
        logging.info(
            "---------Receive Message---------:\n{api}{request_info}\nReturn Message:\n{return_m}\n"
                .format(api=conn_tb, request_info=request_info, return_m=return_msg))
