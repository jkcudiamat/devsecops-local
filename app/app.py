"""
DevSecOps Pipeline - Sample Flask Application
Local / Minikube version — identical app code to cloud version.
"""

from flask import Flask, jsonify, request
import os
import logging

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s [%(levelname)s] %(message)s'
)
logger = logging.getLogger(__name__)

app = Flask(__name__)
APP_VERSION = "1.0.0"


@app.route("/")
def home():
    logger.info("Request received: GET /")
    return jsonify({
        "message": "DevSecOps Pipeline — Live",
        "version": APP_VERSION,
        "status": "healthy"
    })


@app.route("/health")
def health():
    return jsonify({"status": "ok"}), 200


@app.route("/ready")
def ready():
    return jsonify({"status": "ready"}), 200


@app.route("/info")
def info():
    return jsonify({
        "environment": os.getenv("APP_ENV", "production"),
        "hostname": os.getenv("HOSTNAME", "unknown"),
        "version": APP_VERSION
    })


@app.errorhandler(404)
def not_found(e):
    logger.warning(f"404 Not Found: {request.path}")
    return jsonify({"error": "Not Found"}), 404


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)
