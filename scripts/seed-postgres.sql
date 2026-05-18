CREATE TABLE IF NOT EXISTS customers (
    id          SERIAL PRIMARY KEY,
    email       VARCHAR(255) NOT NULL UNIQUE,
    full_name   VARCHAR(255) NOT NULL,
    country     VARCHAR(64)  NOT NULL,
    created_at  TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS orders (
    id           SERIAL PRIMARY KEY,
    customer_id  INTEGER NOT NULL REFERENCES customers(id),
    product      VARCHAR(255) NOT NULL,
    amount_cents INTEGER NOT NULL,
    status       VARCHAR(32) NOT NULL,
    ordered_at   TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

INSERT INTO customers (email, full_name, country) VALUES
    ('alice@example.com', 'Alice Nguyen', 'US'),
    ('bob@example.com', 'Bob Patel', 'IN'),
    ('carol@example.com', 'Carol Schmidt', 'DE'),
    ('dave@example.com', 'Dave Okonkwo', 'NG'),
    ('eve@example.com', 'Eve Tanaka', 'JP')
ON CONFLICT (email) DO NOTHING;

INSERT INTO orders (customer_id, product, amount_cents, status, ordered_at)
SELECT c.id, v.product, v.amount_cents, v.status, v.ordered_at
FROM customers c
JOIN (VALUES
    ('alice@example.com', 'Velero POC License', 4999, 'paid', NOW() - INTERVAL '2 days'),
    ('alice@example.com', 'Migration Support', 19900, 'paid', NOW() - INTERVAL '1 day'),
    ('bob@example.com', 'Postgres Backup Addon', 1299, 'paid', NOW() - INTERVAL '5 hours'),
    ('carol@example.com', 'MySQL Backup Addon', 1299, 'pending', NOW() - INTERVAL '3 hours'),
    ('dave@example.com', 'Cross-cloud Egress Pack', 8900, 'paid', NOW() - INTERVAL '12 hours'),
    ('eve@example.com', 'DR Runbook Template', 0, 'refunded', NOW() - INTERVAL '30 minutes')
) AS v(email, product, amount_cents, status, ordered_at) ON c.email = v.email
WHERE NOT EXISTS (
    SELECT 1 FROM orders o
    WHERE o.customer_id = c.id AND o.product = v.product
);

SELECT 'customers' AS table_name, COUNT(*)::text AS row_count FROM customers
UNION ALL
SELECT 'orders', COUNT(*)::text FROM orders;
