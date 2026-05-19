#!/usr/bin/env -S uv run
"""Count rows in customers and orders tables for MySQL and Postgres."""

import argparse


def count_mysql(args):
    import pymysql
    conn = pymysql.connect(
        host=args.host, port=args.port,
        user=args.user, password=args.password,
        database=args.database,
    )
    cur = conn.cursor()
    cur.execute("SELECT COUNT(*) FROM customers")
    customers = cur.fetchone()[0]
    cur.execute("SELECT COUNT(*) FROM orders")
    orders = cur.fetchone()[0]
    cur.close()
    conn.close()
    print(f"MySQL     — customers: {customers:,}  orders: {orders:,}")


def count_postgres(args):
    import psycopg2
    conn = psycopg2.connect(
        host=args.host, port=args.port,
        user=args.user, password=args.password,
        dbname=args.database,
    )
    cur = conn.cursor()
    cur.execute("SELECT COUNT(*) FROM customers")
    customers = cur.fetchone()[0]
    cur.execute("SELECT COUNT(*) FROM orders")
    orders = cur.fetchone()[0]
    cur.close()
    conn.close()
    print(f"Postgres  — customers: {customers:,}  orders: {orders:,}")


def main():
    parser = argparse.ArgumentParser(description="Count rows in customers/orders tables")
    parser.add_argument("--db", choices=["mysql", "postgres", "all"], default="all")
    parser.add_argument("--host", default="127.0.0.1")
    parser.add_argument("--mysql-port", type=int, default=3306)
    parser.add_argument("--postgres-port", type=int, default=5432)
    parser.add_argument("--user", default="appuser")
    parser.add_argument("--password", default="apppassword")
    parser.add_argument("--database", default="appdb")
    args = parser.parse_args()

    if args.db in ("mysql", "all"):
        args.port = args.mysql_port
        count_mysql(args)
    if args.db in ("postgres", "all"):
        args.port = args.postgres_port
        count_postgres(args)


if __name__ == "__main__":
    main()
