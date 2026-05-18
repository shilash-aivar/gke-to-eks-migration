#!/usr/bin/env python3
"""
Emit structured logs for AKS → EKS Velero / Loki migration POC.

Promtail scrapes stdout. After restore on EKS, query Loki:
  {namespace="databases", app="log-generator"} |= "MIGRATION_POC"

Env:
  LOG_INTERVAL_SEC   seconds between log lines (default: 5)
  LOG_BURST_COUNT    lines per burst (default: 3)
  RUN_ID             stable id for this run (default: hostname)
"""
from __future__ import annotations

import json
import logging
import os
import socket
import sys
import time
import uuid
from datetime import datetime, timezone

MARKER = "MIGRATION_POC"
INTERVAL = float(os.environ.get("LOG_INTERVAL_SEC", "5"))
BURST = int(os.environ.get("LOG_BURST_COUNT", "3"))
RUN_ID = os.environ.get("RUN_ID") or os.environ.get("HOSTNAME", socket.gethostname())
POD = os.environ.get("POD_NAME", "local")
NAMESPACE = os.environ.get("POD_NAMESPACE", "local")
CLUSTER = os.environ.get("CLUSTER_NAME", "unknown")


class JsonFormatter(logging.Formatter):
    def format(self, record: logging.LogRecord) -> str:
        payload = {
            "marker": MARKER,
            "ts": datetime.now(timezone.utc).isoformat(),
            "level": record.levelname,
            "message": record.getMessage(),
            "run_id": RUN_ID,
            "pod": POD,
            "namespace": NAMESPACE,
            "cluster": CLUSTER,
            "seq": getattr(record, "seq", None),
            "event": getattr(record, "event", None),
        }
        return json.dumps(payload, ensure_ascii=False)


def setup_logging() -> logging.Logger:
    logger = logging.getLogger("migration_poc")
    logger.setLevel(logging.DEBUG)
    handler = logging.StreamHandler(sys.stdout)
    handler.setFormatter(JsonFormatter())
    logger.handlers.clear()
    logger.addHandler(handler)
    return logger


def main() -> None:
    logger = setup_logging()
    boot_id = str(uuid.uuid4())[:8]

    logger.info(
        "log generator started",
        extra={
            "seq": 0,
            "event": "startup",
        },
    )
    logger.info(
        f"boot_id={boot_id} interval_sec={INTERVAL} burst={BURST}",
        extra={"seq": 0, "event": "config"},
    )

    seq = 1
    levels = (
        (logging.INFO, "heartbeat"),
        (logging.INFO, "order_processed"),
        (logging.WARNING, "retry_scheduled"),
        (logging.ERROR, "simulated_error"),
    )

    while True:
        for i in range(BURST):
            level, event = levels[(seq + i) % len(levels)]
            record_extra = {
                "seq": seq,
                "event": event,
            }
            msg = (
                f"{MARKER} seq={seq} boot_id={boot_id} "
                f"customer_id={(seq % 5) + 1} order_id={1000 + seq}"
            )
            logger.log(level, msg, extra=record_extra)
            seq += 1
        time.sleep(INTERVAL)


if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        sys.exit(0)
