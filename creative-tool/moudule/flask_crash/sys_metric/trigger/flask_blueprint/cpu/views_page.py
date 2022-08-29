# coding = utf-8
import logging

from flask import Flask, render_template, jsonify
from flask import Blueprint
import json

# 等同于原来在 manage.py里面的 app = Flask()
memory_page_bp = Blueprint('memory_page_bp', __name__, url_prefix='/memory/page')


@memory_page_bp.route('/')
def get_html():
    print("++++")
    return render_template('memory/memory.html')
