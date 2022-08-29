# coding = utf-8
import logging

from flask import Flask, render_template, jsonify
from flask import Blueprint
import json

# 等同于原来在 manage.py里面的 app = Flask()
crash_api_bp = Blueprint('crash_api_bp', __name__, url_prefix='/crash/api')


@crash_api_bp.route('/')
def home():
    return "hello"

