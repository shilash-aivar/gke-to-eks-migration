#!/usr/bin/env python3
"""
Structured log generator for AKS → EKS Velero / Loki migration POC.

Simulates three services (api, worker, scheduler) emitting realistic
JSON logs. Promtail scrapes stdout; after restore on EKS query Loki:
  {namespace="databases", app="log-generator"} |= "MIGRATION_POC"

Env:
  LOG_INTERVAL_SEC    seconds between bursts       (default: 5)
  LOG_BURST_COUNT     log lines per burst          (default: 3)
  LOG_LEVEL           min log level                (default: DEBUG)
  RUN_ID              stable id for this run       (default: hostname)
  CLUSTER_NAME        cluster label in logs        (default: unknown)
  POD_NAME            pod label in logs            (default: local)
  POD_NAMESPACE       namespace label in logs      (default: local)
"""
from __future__ import annotations

import json
import logging
import os
import random
import signal
import socket
import sys
import time
import uuid
from datetime import datetime, timezone
from typing import Any

# ── Config ────────────────────────────────────────────────────────────────────

MARKER    = "MIGRATION_POC"
INTERVAL  = float(os.environ.get("LOG_INTERVAL_SEC", "5"))
BURST     = int(os.environ.get("LOG_BURST_COUNT", "3"))
LOG_LEVEL = os.environ.get("LOG_LEVEL", "DEBUG").upper()
RUN_ID    = os.environ.get("RUN_ID") or os.environ.get("HOSTNAME", socket.gethostname())
POD       = os.environ.get("POD_NAME", "local")
NAMESPACE = os.environ.get("POD_NAMESPACE", "local")
CLUSTER   = os.environ.get("CLUSTER_NAME", "unknown")

# ── Simulated data pools ──────────────────────────────────────────────────────

PRODUCTS = [
    "Velero POC License", "Migration Support", "Postgres Backup Addon",
    "MySQL Backup Addon", "Cross-cloud Egress Pack", "DR Runbook Template",
    "EKS Managed Node Pack", "AKS to EKS Migration Kit",
    "Multi-cluster Monitoring", "Disaster Recovery Bundle",
]

STATUSES   = ["paid", "pending", "refunded", "failed"]
COUNTRIES  = ["US", "IN", "DE", "NG", "JP", "GB", "BR", "AU", "FR", "CA"]
HTTP_PATHS = ["/api/orders", "/api/customers", "/api/backups", "/api/restore",
              "/healthz", "/metrics", "/api/products", "/api/invoices"]
HTTP_METHODS  = ["GET", "GET", "GET", "POST", "POST", "PUT", "DELETE"]
ERROR_REASONS = [
    "connection timeout", "upstream unavailable", "rate limit exceeded",
    "invalid payload", "auth token expired", "database deadlock",
    "disk quota exceeded", "pod OOMKilled",
]
DB_OPS = ["SELECT", "INSERT", "UPDATE", "DELETE"]

# ── Weighted event registry ───────────────────────────────────────────────────
# Each entry: (weight, level, service, event_fn)
# Higher weight = more frequent.

def _api_request() -> dict[str, Any]:
    latency = round(random.lognormvariate(4.5, 0.8))  # realistic ms spread
    status  = random.choices([200, 201, 400, 401, 404, 500],
                              weights=[60, 10, 8, 5, 10, 7])[0]
    return {
        "event":   "http_request",
        "method":  random.choice(HTTP_METHODS),
        "path":    random.choice(HTTP_PATHS),
        "status":  status,
        "latency_ms": latency,
        "customer_id": random.randint(1, 500),
    }

def _order_processed() -> dict[str, Any]:
    return {
        "event":      "order_processed",
        "order_id":   random.randint(10000, 99999),
        "customer_id": random.randint(1, 500),
        "product":    random.choice(PRODUCTS),
        "amount_cents": random.choice([999, 1299, 4999, 8900, 14900, 19900, 24900]),
        "status":     random.choice(STATUSES),
        "country":    random.choice(COUNTRIES),
    }

def _db_query() -> dict[str, Any]:
    duration = round(random.lognormvariate(3.0, 1.0))
    return {
        "event":       "db_query",
        "operation":   random.choice(DB_OPS),
        "table":       random.choice(["customers", "orders", "products", "invoices"]),
        "duration_ms": duration,
        "rows_affected": random.randint(0, 500),
    }

def _backup_event() -> dict[str, Any]:
    phase = random.choices(
        ["InProgress", "Completed", "Failed"],
        weights=[20, 70, 10]
    )[0]
    return {
        "event":       "velero_backup",
        "backup_name": f"poc-backup-{datetime.now(timezone.utc).strftime('%Y%m%d')}",
        "phase":       phase,
        "items_backed_up": random.randint(10, 500) if phase != "Failed" else 0,
        "duration_sec": random.randint(5, 120),
    }

def _retry_scheduled() -> dict[str, Any]:
    return {
        "event":      "retry_scheduled",
        "job":        random.choice(["order-sync", "invoice-gen", "report-export", "db-cleanup"]),
        "attempt":    random.randint(1, 5),
        "delay_sec":  random.choice([5, 10, 30, 60, 300]),
        "reason":     random.choice(ERROR_REASONS),
    }

def _simulated_error() -> dict[str, Any]:
    return {
        "event":  "error",
        "reason": random.choice(ERROR_REASONS),
        "component": random.choice(["api-server", "worker", "scheduler", "db-pool"]),
        "customer_id": random.randint(1, 500),
    }

def _heartbeat() -> dict[str, Any]:
    return {
        "event":      "heartbeat",
        "uptime_sec": int(time.monotonic()),
        "goroutines": random.randint(8, 64),
        "mem_mb":     round(random.uniform(40, 200), 1),
    }

def _cache_event() -> dict[str, Any]:
    hit = random.random() > 0.3
    return {
        "event":     "cache_lookup",
        "key":       f"customer:{random.randint(1, 500)}",
        "hit":       hit,
        "ttl_sec":   random.randint(30, 300) if hit else 0,
    }

# (weight, level, service, event_fn)
EVENT_REGISTRY = [
    (40, logging.INFO,    "api",       _api_request),
    (20, logging.INFO,    "worker",    _order_processed),
    (15, logging.DEBUG,   "worker",    _db_query),
    (10, logging.INFO,    "scheduler", _heartbeat),
    (5,  logging.INFO,    "scheduler", _backup_event),
    (5,  logging.WARNING, "worker",    _retry_scheduled),
    (3,  logging.ERROR,   "api",       _simulated_error),
    (2,  logging.DEBUG,   "api",       _cache_event),
]

_WEIGHTS  = [e[0] for e in EVENT_REGISTRY]
_REGISTRY = EVENT_REGISTRY

# ── Formatter ────────────────────────────────────────────────────────────────

class JsonFormatter(logging.Formatter):
    def format(self, record: logging.LogRecord) -> str:
        payload: dict[str, Any] = {
            "marker":    MARKER,
            "ts":        datetime.now(timezone.utc).isoformat(),
            "level":     record.levelname,
            "message":   record.getMessage(),
            "run_id":    RUN_ID,
            "pod":       POD,
            "namespace": NAMESPACE,
            "cluster":   CLUSTER,
            "seq":       getattr(record, "seq", None),
            "service":   getattr(record, "service", None),
        }
        payload.update(getattr(record, "details", {}))
        return json.dumps(payload, ensure_ascii=False)


def setup_logging() -> logging.Logger:
    logger = logging.getLogger("migration_poc")
    logger.setLevel(getattr(logging, LOG_LEVEL, logging.DEBUG))
    handler = logging.StreamHandler(sys.stdout)
    handler.setFormatter(JsonFormatter())
    logger.handlers.clear()
    logger.addHandler(handler)
    return logger

# ── Main ──────────────────────────────────────────────────────────────────────

def main() -> None:
    logger  = setup_logging()
    boot_id = str(uuid.uuid4())[:8]
    seq     = 0

    def _shutdown(signum, frame):
        logger.info("shutting down", extra={"seq": seq, "service": "main",
                                             "details": {"event": "shutdown", "boot_id": boot_id}})
        sys.exit(0)

    signal.signal(signal.SIGTERM, _shutdown)
    signal.signal(signal.SIGINT,  _shutdown)

    logger.info(
        f"log generator started boot_id={boot_id}",
        extra={"seq": seq, "service": "main",
               "details": {"event": "startup", "boot_id": boot_id,
                            "interval_sec": INTERVAL, "burst": BURST}},
    )

    while True:
        for _ in range(BURST):
            seq += 1
            _, level, service, event_fn = random.choices(_REGISTRY, weights=_WEIGHTS, k=1)[0]
            details = event_fn()
            msg = (
                f"{MARKER} seq={seq} service={service} "
                f"event={details.get('event', '?')} boot_id={boot_id}"
            )
            logger.log(level, msg, extra={"seq": seq, "service": service, "details": details})

        time.sleep(INTERVAL)


if __name__ == "__main__":
    main()
