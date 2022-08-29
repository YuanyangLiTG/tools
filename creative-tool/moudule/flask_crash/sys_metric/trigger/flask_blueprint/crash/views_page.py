# coding = utf-8
import logging

from flask import Flask, render_template, jsonify
from flask import Blueprint
import json

# 等同于原来在 manage.py里面的 app = Flask()
crash_page_bp = Blueprint('crash_page_bp', __name__, url_prefix='/crash/page')


@crash_page_bp.route('/')
def get_html():
    print("++++")
    return render_template('crash/index.html')
