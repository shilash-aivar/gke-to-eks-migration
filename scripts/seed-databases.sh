#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
NS="${NS:-databases}"

echo "==> Seeding Postgres (postgres-0)"
kubectl -n "${NS}" exec -i postgres-0 -- psql -U appuser -d appdb \
  < "${ROOT}/scripts/seed-postgres.sql"

echo ""
echo "==> Seeding MySQL (mysql-0)"
kubectl -n "${NS}" exec -i mysql-0 -- mysql -u appuser -papppassword appdb \
  < "${ROOT}/scripts/seed-mysql.sql"

echo ""
echo "==> Sample rows (Postgres)"
kubectl -n "${NS}" exec postgres-0 -- psql -U appuser -d appdb -c \
  "SELECT c.full_name, o.product, o.amount_cents, o.status FROM orders o JOIN customers c ON c.id = o.customer_id ORDER BY o.id;"

echo ""
echo "==> Sample rows (MySQL)"
kubectl -n "${NS}" exec mysql-0 -- mysql -u appuser -papppassword appdb -e \
  "SELECT c.full_name, o.product, o.amount_cents, o.status FROM orders o JOIN customers c ON c.id = o.customer_id ORDER BY o.id;"
