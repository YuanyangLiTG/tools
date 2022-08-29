# coding = utf-8
import logging

from flask import Flask, render_template, jsonify
from flask import Blueprint
import json

# 等同于原来在 manage.py里面的 app = Flask()
memory_api_bp = Blueprint('memory_api_bp', __name__, url_prefix='/memory/api')


@memory_api_bp.route('/')
def home():
    return "hello"

