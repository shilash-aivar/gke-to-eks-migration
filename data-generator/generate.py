#!/usr/bin/env -S uv run
"""
Fake data generator for customers and orders tables.
Supports MySQL and PostgreSQL with chunked inserts for large volumes.

Usage:
    python generate.py --db mysql --host localhost --port 3306 \
        --user root --password secret --database migration_db \
        --customers 100 --orders-per-customer 3

    python generate.py --db postgres --host localhost --port 5432 \
        --user postgres --password secret --database migration_db \
        --customers 1000000 --batch-size 5000
"""

import argparse
import random
import time
from datetime import datetime, timedelta

from faker import Faker
from tqdm import tqdm

fake = Faker()
RUN_ID = hex(int(time.time() * 1000))[-6:]  # unique suffix per run

PRODUCTS = [
    ("Velero POC License", 4999),
    ("Migration Support", 19900),
    ("Postgres Backup Addon", 1299),
    ("MySQL Backup Addon", 1299),
    ("Cross-cloud Egress Pack", 8900),
    ("DR Runbook Template", 0),
    ("EKS Managed Node Pack", 9900),
    ("AKS to EKS Migration Kit", 14900),
    ("Multi-cluster Monitoring", 7500),
    ("Disaster Recovery Bundle", 24900),
]

STATUSES = ["paid", "paid", "paid", "pending", "refunded"]


def random_timestamp(days_back=90):
    delta = timedelta(
        days=random.randint(0, days_back),
        hours=random.randint(0, 23),
        minutes=random.randint(0, 59),
        seconds=random.randint(0, 59),
    )
    return datetime.now().replace(microsecond=0) - delta


def customer_batch(size):
    batch = []
    for _ in range(size):
        local, domain = fake.unique.email().split("@", 1)
        batch.append({
            "email": f"{local}+{RUN_ID}@{domain}",
            "full_name": fake.name(),
            "country": fake.country_code(),
            "created_at": random_timestamp(),
        })
    return batch


def order_batch(customer_ids, orders_per_customer):
    batch = []
    for customer_id in customer_ids:
        count = random.randint(*orders_per_customer)
        for _ in range(count):
            product, price = random.choice(PRODUCTS)
            batch.append({
                "customer_id": customer_id,
                "product": product,
                "amount_cents": price,
                "status": random.choice(STATUSES),
                "ordered_at": random_timestamp(),
            })
    return batch


def seed_mysql(args):
    import pymysql

    conn = pymysql.connect(
        host=args.host,
        port=args.port,
        user=args.user,
        password=args.password,
        database=args.database,
        autocommit=False,
    )
    cur = conn.cursor()

    cur.execute("""
        CREATE TABLE IF NOT EXISTS customers (
            id INT AUTO_INCREMENT PRIMARY KEY,
            email VARCHAR(255) UNIQUE NOT NULL,
            full_name VARCHAR(255),
            country CHAR(2),
            created_at DATETIME
        )
    """)
    cur.execute("""
        CREATE TABLE IF NOT EXISTS orders (
            id INT AUTO_INCREMENT PRIMARY KEY,
            customer_id INT NOT NULL,
            product VARCHAR(255),
            amount_cents INT,
            status VARCHAR(50),
            ordered_at DATETIME,
            FOREIGN KEY (customer_id) REFERENCES customers(id)
        )
    """)
    conn.commit()

    total_customers = 0
    total_orders = 0
    remaining = args.customers

    print(f"Inserting {args.customers:,} customers in batches of {args.batch_size:,}...")
    with tqdm(total=args.customers, unit="customers") as pbar:
        while remaining > 0:
            batch_size = min(args.batch_size, remaining)
            customers = customer_batch(batch_size)

            cur.executemany(
                """
                INSERT IGNORE INTO customers (email, full_name, country, created_at)
                VALUES (%(email)s, %(full_name)s, %(country)s, %(created_at)s)
                """,
                customers,
            )
            conn.commit()
            total_customers += batch_size
            remaining -= batch_size
            pbar.update(batch_size)

    print(f"Fetching inserted customer IDs...")
    cur.execute("SELECT id FROM customers")
    all_customer_ids = [row[0] for row in cur.fetchall()]

    print(f"Inserting orders ({args.orders_min}–{args.orders_max} per customer)...")
    id_chunks = [
        all_customer_ids[i:i + args.batch_size]
        for i in range(0, len(all_customer_ids), args.batch_size)
    ]
    with tqdm(total=len(all_customer_ids), unit="customers") as pbar:
        for chunk in id_chunks:
            orders = order_batch(chunk, (args.orders_min, args.orders_max))
            cur.executemany(
                """
                INSERT INTO orders (customer_id, product, amount_cents, status, ordered_at)
                VALUES (%(customer_id)s, %(product)s, %(amount_cents)s, %(status)s, %(ordered_at)s)
                """,
                orders,
            )
            conn.commit()
            total_orders += len(orders)
            pbar.update(len(chunk))

    cur.close()
    conn.close()
    print(f"\nDone. MySQL: {total_customers:,} customers, {total_orders:,} orders.")


def seed_postgres(args):
    import psycopg2
    import psycopg2.extras

    conn = psycopg2.connect(
        host=args.host,
        port=args.port,
        user=args.user,
        password=args.password,
        dbname=args.database,
    )
    conn.autocommit = False
    cur = conn.cursor()

    cur.execute("""
        CREATE TABLE IF NOT EXISTS customers (
            id SERIAL PRIMARY KEY,
            email VARCHAR(255) UNIQUE NOT NULL,
            full_name VARCHAR(255),
            country CHAR(2),
            created_at TIMESTAMP
        )
    """)
    cur.execute("""
        CREATE TABLE IF NOT EXISTS orders (
            id SERIAL PRIMARY KEY,
            customer_id INT NOT NULL REFERENCES customers(id),
            product VARCHAR(255),
            amount_cents INT,
            status VARCHAR(50),
            ordered_at TIMESTAMP
        )
    """)
    conn.commit()

    total_customers = 0
    total_orders = 0
    remaining = args.customers

    print(f"Inserting {args.customers:,} customers in batches of {args.batch_size:,}...")
    with tqdm(total=args.customers, unit="customers") as pbar:
        while remaining > 0:
            batch_size = min(args.batch_size, remaining)
            customers = customer_batch(batch_size)

            psycopg2.extras.execute_batch(
                cur,
                """
                INSERT INTO customers (email, full_name, country, created_at)
                VALUES (%(email)s, %(full_name)s, %(country)s, %(created_at)s)
                ON CONFLICT (email) DO NOTHING
                """,
                customers,
                page_size=1000,
            )
            conn.commit()
            total_customers += batch_size
            remaining -= batch_size
            pbar.update(batch_size)

    print(f"Fetching inserted customer IDs...")
    cur.execute("SELECT id FROM customers")
    all_customer_ids = [row[0] for row in cur.fetchall()]

    print(f"Inserting orders ({args.orders_min}–{args.orders_max} per customer)...")
    id_chunks = [
        all_customer_ids[i:i + args.batch_size]
        for i in range(0, len(all_customer_ids), args.batch_size)
    ]
    with tqdm(total=len(all_customer_ids), unit="customers") as pbar:
        for chunk in id_chunks:
            orders = order_batch(chunk, (args.orders_min, args.orders_max))
            psycopg2.extras.execute_batch(
                cur,
                """
                INSERT INTO orders (customer_id, product, amount_cents, status, ordered_at)
                VALUES (%(customer_id)s, %(product)s, %(amount_cents)s, %(status)s, %(ordered_at)s)
                """,
                orders,
                page_size=1000,
            )
            conn.commit()
            total_orders += len(orders)
            pbar.update(len(chunk))

    cur.close()
    conn.close()
    print(f"\nDone. Postgres: {total_customers:,} customers, {total_orders:,} orders.")


def main():
    parser = argparse.ArgumentParser(description="Fake data generator using Faker")
    parser.add_argument("--db", choices=["mysql", "postgres"], required=True)
    parser.add_argument("--host", default="localhost")
    parser.add_argument("--port", type=int)
    parser.add_argument("--user", required=True)
    parser.add_argument("--password", required=True)
    parser.add_argument("--database", required=True)
    parser.add_argument("--customers", type=int, default=100,
                        help="Number of customers to generate (e.g. 100, 1000000)")
    parser.add_argument("--orders-min", type=int, default=1,
                        help="Minimum orders per customer")
    parser.add_argument("--orders-max", type=int, default=5,
                        help="Maximum orders per customer")
    parser.add_argument("--batch-size", type=int, default=1000,
                        help="Insert batch size (tune for performance)")
    args = parser.parse_args()

    if args.port is None:
        args.port = 3306 if args.db == "mysql" else 5432

    if args.db == "mysql":
        seed_mysql(args)
    else:
        seed_postgres(args)


if __name__ == "__main__":
    main()
