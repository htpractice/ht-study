"""Order API v2 — OTEL traces + metrics, JSON logs correlated with trace_id, Prometheus /metrics."""
import json
import logging
import os
import random
import time
import uuid
from datetime import datetime, timezone

from flask import Flask, request
from opentelemetry import metrics, trace
from opentelemetry.exporter.otlp.proto.grpc.metric_exporter import OTLPMetricExporter
from opentelemetry.exporter.otlp.proto.grpc.trace_exporter import OTLPSpanExporter
from opentelemetry.instrumentation.flask import FlaskInstrumentor
from opentelemetry.instrumentation.logging import LoggingInstrumentor
from opentelemetry.sdk.metrics import MeterProvider
from opentelemetry.sdk.metrics.export import PeriodicExportingMetricReader
from opentelemetry.sdk.resources import Resource
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor
from prometheus_client import Counter, Histogram, generate_latest

SERVICE_NAME = os.getenv("OTEL_SERVICE_NAME", "order-api")
SERVICE_VERSION = os.getenv("SERVICE_VERSION", "v2")
DEPLOYMENT_ENV = os.getenv("DEPLOYMENT_ENV", "lab")
OTLP_ENDPOINT = os.getenv("OTEL_EXPORTER_OTLP_ENDPOINT", "http://localhost:4317")

resource = Resource.create(
    {
        "service.name": SERVICE_NAME,
        "service.version": SERVICE_VERSION,
        "deployment.environment": DEPLOYMENT_ENV,
        "service.namespace": "order-api",
    }
)

# --- Traces → OTLP → Collector → Jaeger ---
trace_provider = TracerProvider(resource=resource)
trace_provider.add_span_processor(
    BatchSpanProcessor(OTLPSpanExporter(endpoint=OTLP_ENDPOINT, insecure=True))
)
trace.set_tracer_provider(trace_provider)
tracer = trace.get_tracer(SERVICE_NAME, SERVICE_VERSION)

# --- OTEL metrics → OTLP → Collector → Prometheus exporter ---
metric_reader = PeriodicExportingMetricReader(
    OTLPMetricExporter(endpoint=OTLP_ENDPOINT, insecure=True),
    export_interval_millis=15000,
)
metrics.set_meter_provider(MeterProvider(resource=resource, metric_readers=[metric_reader]))
meter = metrics.get_meter(SERVICE_NAME, SERVICE_VERSION)
otel_orders_created = meter.create_counter(
    "orders.created",
    description="Orders successfully created",
    unit="1",
)
otel_payment_errors = meter.create_counter(
    "payment.errors",
    description="Payment gateway failures",
    unit="1",
)

app = Flask(__name__)
FlaskInstrumentor().instrument_app(app)

# Prometheus scrape metrics (Part A — compare side-by-side with OTEL path)
REQUESTS = Counter("http_requests_total", "Total HTTP requests", ["method", "endpoint", "status"])
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
        span = trace.get_current_span()
        ctx = span.get_span_context()
        if ctx.is_valid:
            payload["trace_id"] = format(ctx.trace_id, "032x")
            payload["span_id"] = format(ctx.span_id, "016x")
        for key in ("order_id", "method", "path", "status", "latency_ms", "product"):
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
    LoggingInstrumentor().instrument(set_logging_format=False)


configure_logging()
log = logging.getLogger("order-api")


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
    return {"service": SERVICE_NAME, "version": SERVICE_VERSION}, 200


@app.post("/order")
def create_order():
    order_id = f"ord-{uuid.uuid4().hex[:10]}"
    product = (request.json or {}).get("product", "widget")

    with tracer.start_as_current_span("create_order") as span:
        span.set_attribute("order.id", order_id)
        span.set_attribute("product.name", product)
        span.set_attribute("payment.gateway", "mock-payments")
        span.set_attribute("service.name", SERVICE_NAME)

        log.info("order_received", extra={"order_id": order_id})

        with tracer.start_as_current_span("payment.charge") as pay_span:
            pay_span.set_attribute("payment.gateway", "mock-payments")
            pay_span.set_attribute("order.id", order_id)
            time.sleep(random.uniform(0.02, 0.08))

            if random.random() < 0.15:
                pay_span.set_attribute("payment.result", "timeout")
                pay_span.set_attribute("http.response.status_code", 503)
                span.set_attribute("http.response.status_code", 503)
                otel_payment_errors.add(1, {"payment.gateway": "mock-payments"})
                log.error("payment_gateway_timeout", extra={"order_id": order_id})
                return {"error": "payment timeout", "order_id": order_id}, 503

            pay_span.set_attribute("payment.result", "success")

        time.sleep(random.uniform(0.05, 0.2))
        ORDERS_CREATED.inc()
        otel_orders_created.add(1, {"product.name": product})
        span.set_attribute("http.response.status_code", 201)
        log.info("order_created", extra={"order_id": order_id, "product": product})
        return {"order_id": order_id, "product": product, "status": "confirmed"}, 201


@app.get("/metrics")
def metrics():
    return generate_latest(), 200, {"Content-Type": "text/plain; charset=utf-8"}


if __name__ == "__main__":
    port = int(os.getenv("PORT", "8080"))
    app.run(host="0.0.0.0", port=port)
