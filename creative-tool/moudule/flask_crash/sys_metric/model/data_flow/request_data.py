# coding=utf-8

class BeforeRequest:
    pass


class AfterRequest:

    @classmethod
    def test(cls):
        print("AfterRequest")

    @classmethod
    def show(cls,response):
        print("response:{}".format(response))
