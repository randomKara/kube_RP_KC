from flask import Flask, request, render_template
import os

app = Flask(__name__)

@app.route('/')
def home():
    user_info = {
        'name': request.headers.get('X-User-Name'),
        'roles': request.headers.get('X-User-Roles')
    }
    return render_template('user_info.html', user=user_info)

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, debug=True) 