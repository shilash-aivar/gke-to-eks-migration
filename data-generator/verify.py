#!/usr/bin/env -S uv run
"""Verify data parity between AKS (source) and EKS (destination)."""

import sys
import argparse


def query_counts(db: str, host: str, port: int, user: str, password: str, database: str) -> dict:
    if db == "mysql":
        import pymysql
        conn = pymysql.connect(host=host, port=port, user=user, password=password, database=database)
    else:
        import psycopg2
        conn = psycopg2.connect(host=host, port=port, user=user, password=password, dbname=database)

    cur = conn.cursor()
    cur.execute("SELECT COUNT(*) FROM customers")
    customers = cur.fetchone()[0]
    cur.execute("SELECT COUNT(*) FROM orders")
    orders = cur.fetchone()[0]
    cur.close()
    conn.close()
    return {"customers": customers, "orders": orders}


def check(label: str, src: dict, dst: dict) -> bool:
    ok = src == dst
    status = "PASS" if ok else "FAIL"
    print(f"  [{status}] {label}")
    print(f"         AKS → customers: {src['customers']:,}  orders: {src['orders']:,}")
    print(f"         EKS → customers: {dst['customers']:,}  orders: {dst['orders']:,}")
    if not ok:
        diff_c = dst["customers"] - src["customers"]
        diff_o = dst["orders"] - src["orders"]
        print(f"         DIFF  customers: {diff_c:+,}  orders: {diff_o:+,}")
    return ok


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--mysql-aks-port",     type=int, default=3307)
    parser.add_argument("--mysql-eks-port",     type=int, default=3308)
    parser.add_argument("--postgres-aks-port",  type=int, default=5433)
    parser.add_argument("--postgres-eks-port",  type=int, default=5434)
    parser.add_argument("--user",     default="appuser")
    parser.add_argument("--password", default="apppassword")
    parser.add_argument("--database", default="appdb")
    args = parser.parse_args()

    print("Migration verification")
    print("=" * 44)

    results = []

    # MySQL
    src = query_counts("mysql",    "127.0.0.1", args.mysql_aks_port,    args.user, args.password, args.database)
    dst = query_counts("mysql",    "127.0.0.1", args.mysql_eks_port,    args.user, args.password, args.database)
    results.append(check("MySQL", src, dst))

    print()

    # Postgres
    src = query_counts("postgres", "127.0.0.1", args.postgres_aks_port, args.user, args.password, args.database)
    dst = query_counts("postgres", "127.0.0.1", args.postgres_eks_port, args.user, args.password, args.database)
    results.append(check("Postgres", src, dst))

    print()
    if all(results):
        print("Overall: PASS — AKS and EKS data match")
        sys.exit(0)
    else:
        print("Overall: FAIL — data mismatch detected")
        sys.exit(1)


if __name__ == "__main__":
    main()
