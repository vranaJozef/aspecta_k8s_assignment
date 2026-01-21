import logging
import os
from http import HTTPStatus
from flask import Flask, jsonify
from prometheus_flask_exporter import PrometheusMetrics

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

class Config:
    """Application configuration."""
    APP_ENV = os.getenv("APP_ENV", "development")
    PORT = int(os.getenv("PORT", 5000))

app = Flask(__name__)
app.config.from_object(Config)

# Initialize Prometheus Metrics (exports to /metrics by default)
metrics = PrometheusMetrics(app)
# Add static information as a metric
metrics.info('app_info', 'Application info', version='1.0.0', env=Config.APP_ENV)

@app.route("/health")
def health_check():
    """Health check endpoint for liveness probes."""
    return jsonify({"status": "healthy"}), HTTPStatus.OK

@app.route("/ready")
def readiness_check():
    """Readiness check endpoint."""
    return jsonify({"status": "ready"}), HTTPStatus.OK

@app.route("/api")
def api_root():
    """Root API endpoint returning environment info."""
    logger.info(f"API request received in {Config.APP_ENV} environment")
    return jsonify({
        "message": "Hello from Backend!",
        "environment": Config.APP_ENV
    }), HTTPStatus.OK

if __name__ == "__main__":
    logger.info(f"Starting application in {Config.APP_ENV} mode on port {Config.PORT}")
    app.run(host="0.0.0.0", port=Config.PORT)
