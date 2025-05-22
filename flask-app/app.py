from flask import Flask
import os

app = Flask(__name__)

@app.route('/')
def hello_world():
    hostname = os.uname().nodename
    return f"Hello from Flask! Running on container hostname: {hostname}"

if __name__ == '__main__':
    # Flask application listens on all interfaces (0.0.0.0) inside its container.
    # This is crucial for it to be accessible from other containers in the same Docker network
    # (like the Tailscale sidecar).
    app.run(host='0.0.0.0', port=5000)
