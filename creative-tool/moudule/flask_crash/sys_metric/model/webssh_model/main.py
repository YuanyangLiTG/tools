import asyncio
import logging
import tornado.web
import tornado.ioloop

from tornado.options import options
from webssh import handler
from webssh.handler import IndexHandler, WsockHandler, NotFoundHandler
from webssh.settings import (
    get_app_settings, get_host_keys_settings, get_policy_setting,
    get_ssl_context, get_server_settings, check_encoding_setting
)
import const as common_const


# def make_handlers(loop, options):
#     host_keys_settings = get_host_keys_settings(options)
#     policy = get_policy_setting(options, host_keys_settings)
#
#     handlers = [
#         (r'/', IndexHandler, dict(loop=loop, policy=policy,
#                                   host_keys_settings=host_keys_settings)),
#         (r'/ws', WsockHandler, dict(loop=loop))
#     ]
#     return handlers
#
#
# def make_app(handlers, settings):
#     settings.update(default_handler_class=NotFoundHandler)
#     return tornado.web.Application(handlers, **settings)
#
#
# def app_listen(app, port, address, server_settings):
#     app.listen(port, address, **server_settings)
#     print("port:{}-addr:{}-server_setting:".format(port, address))
#     if not server_settings.get('ssl_options'):
#         server_type = 'http'
#     else:
#         server_type = 'https'
#         handler.redirecting = True if options.redirect else False
#     logging.info(
#         'Listening on {}:{} ({})'.format(address, port, server_type)
#     )
#
#
# def main():
#     options.parse_command_line()
#     check_encoding_setting(options.encoding)
#     loop = tornado.ioloop.IOLoop.current()
#     app = make_app(make_handlers(loop, options), get_app_settings(options))
#     ssl_ctx = get_ssl_context(options)
#     server_settings = get_server_settings(options)
#     app_listen(app, options.port, options.address, server_settings)
#     if ssl_ctx:
#         server_settings.update(ssl_options=ssl_ctx)
#         app_listen(app, options.sslport, options.ssladdress, server_settings)
#     loop.start()
#
#
# def do_main():
#     options.parse_command_line()
#     check_encoding_setting(options.encoding)
#     loop = tornado.ioloop.IOLoop.current()
#     app = make_app(make_handlers(loop, options), get_app_settings(options))
#     ssl_ctx = get_ssl_context(options)
#     server_settings = get_server_settings(options)
#     app_listen(app, common_const.web_ssh_port, common_const.web_ssh_ip, server_settings)
#     if ssl_ctx:
#         server_settings.update(ssl_options=ssl_ctx)
#         app_listen(app, options.sslport, options.ssladdress, server_settings)
#     loop.start()


class WebsshServer:
    """
    Webssh服务端
    """

    def __init__(self):
        self.web_ssh_ip = common_const.web_ssh_ip
        self.web_ssh_port = common_const.web_ssh_port
        try:
            asyncio.get_event_loop()
        except RuntimeError:
            asyncio.set_event_loop(asyncio.new_event_loop())
        logging.info("Webssh server is started on:{}:{}".format(self.web_ssh_ip, self.web_ssh_port))

    def run_server(self):
        options.parse_command_line()
        check_encoding_setting(options.encoding)
        loop = tornado.ioloop.IOLoop.current()
        app = self.make_app(self.make_handlers(loop, options), get_app_settings(options))
        ssl_ctx = get_ssl_context(options)
        server_settings = get_server_settings(options)
        self.app_listen(app, common_const.web_ssh_port, common_const.web_ssh_ip, server_settings)
        if ssl_ctx:
            server_settings.update(ssl_options=ssl_ctx)
            self.app_listen(app, options.sslport, options.ssladdress, server_settings)
        loop.start()

    def make_handlers(self,loop, options):
        host_keys_settings = get_host_keys_settings(options)
        policy = get_policy_setting(options, host_keys_settings)

        handlers = [
            (r'/', IndexHandler, dict(loop=loop, policy=policy,
                                      host_keys_settings=host_keys_settings)),
            (r'/ws', WsockHandler, dict(loop=loop))
        ]
        return handlers

    def make_app(self,handlers, settings):
        settings.update(default_handler_class=NotFoundHandler)
        return tornado.web.Application(handlers, **settings)

    def app_listen(self,app, port, address, server_settings):
        app.listen(port, address, **server_settings)
        if not server_settings.get('ssl_options'):
            server_type = 'http'
        else:
            server_type = 'https'
            handler.redirecting = True if options.redirect else False
        logging.info(
            'Listening on {}:{} ({})'.format(address, port, server_type)
        )

