from flask import Flask 
from flask import jsonify 
import socket, os 

app = Flask(__name__)

@app.route('/')
def print_the_ip():
    hostname = socket.gethostname()
    get_local_ip = socket.gethostbyname(hostname)
    return get_local_ip

@app.route('/healthz')
def print_check():
    return "Yes, application is running - CHECK complete"

@app.route('/name')
def print_name():
    return "Harsha Jain"

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8080)
