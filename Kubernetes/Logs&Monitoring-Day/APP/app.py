"""Order API — structured JSON logs + Prometheus metrics for K8s observability lab."""
import json
import logging
import os
import random
import time
import uuid
from datetime import datetime, timezone

from flask import Flask, request
from prometheus_client import Counter, Histogram, generate_latest

app = Flask(__name__)

REQUESTS = Counter(
    "http_requests_total",
    "Total HTTP requests",
    ["method", "endpoint", "status"],
)
LATENCY = Histogram(
    "http_request_duration_seconds",
    "HTTP request latency",
    ["method", "endpoint"],
    buckets=(0.01, 0.05, 0.1, 0.25, 0.5, 1.0, 2.5),
)
ORDERS_CREATED = Counter("orders_created_total", "Orders successfully created")


class JsonFormatter(logging.Formatter):
    def format(self, record: logging.LogRecord) -> str:
        payload = {
            "timestamp": datetime.now(timezone.utc).isoformat(),
            "level": record.levelname,
            "logger": record.name,
            "message": record.getMessage(),
        }
        for key in ("trace_id", "order_id", "method", "path", "status", "latency_ms", "product"):
            if hasattr(record, key):
                payload[key] = getattr(record, key)
        return json.dumps(payload)


def configure_logging() -> None:
    handler = logging.StreamHandler()
    handler.setFormatter(JsonFormatter())
    root = logging.getLogger()
    root.handlers.clear()
    root.addHandler(handler)
    root.setLevel(os.getenv("LOG_LEVEL", "INFO"))


configure_logging()
log = logging.getLogger("order-api")


def trace_id() -> str:
    return request.headers.get("X-Trace-Id", str(uuid.uuid4())[:8])


@app.before_request
def start_timer() -> None:
    request.start_time = time.perf_counter()


@app.after_request
def observe(response):
    elapsed = time.perf_counter() - request.start_time
    endpoint = request.endpoint or "unknown"
    LATENCY.labels(request.method, endpoint).observe(elapsed)
    REQUESTS.labels(request.method, endpoint, response.status_code).inc()

    extra = {
        "trace_id": trace_id(),
        "method": request.method,
        "path": request.path,
        "status": response.status_code,
        "latency_ms": round(elapsed * 1000, 2),
    }
    level = logging.WARNING if response.status_code >= 400 else logging.INFO
    log.log(level, "request_completed", extra=extra)
    return response


@app.get("/health")
def health():
    return {"status": "ok"}, 200


@app.get("/")
def root():
    return {"service": "order-api", "version": "v1"}, 200


@app.post("/order")
def create_order():
    tid = trace_id()
    order_id = f"ord-{uuid.uuid4().hex[:10]}"
    product = (request.json or {}).get("product", "widget")

    log.info("order_received", extra={"trace_id": tid, "order_id": order_id})

    if random.random() < 0.15:
        log.error(
            "payment_gateway_timeout",
            extra={"trace_id": tid, "order_id": order_id},
        )
        return {"error": "payment timeout", "order_id": order_id}, 503

    time.sleep(random.uniform(0.05, 0.3))
    ORDERS_CREATED.inc()
    log.info(
        "order_created",
        extra={"trace_id": tid, "order_id": order_id, "product": product},
    )
    return {"order_id": order_id, "product": product, "status": "confirmed"}, 201


@app.get("/metrics")
def metrics():
    return generate_latest(), 200, {"Content-Type": "text/plain; charset=utf-8"}


if __name__ == "__main__":
    port = int(os.getenv("PORT", "8080"))
    app.run(host="0.0.0.0", port=port)
