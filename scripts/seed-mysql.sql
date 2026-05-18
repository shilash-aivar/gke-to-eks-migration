CREATE TABLE IF NOT EXISTS customers (
    id         INT AUTO_INCREMENT PRIMARY KEY,
    email      VARCHAR(255) NOT NULL UNIQUE,
    full_name  VARCHAR(255) NOT NULL,
    country    VARCHAR(64)  NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS orders (
    id           INT AUTO_INCREMENT PRIMARY KEY,
    customer_id  INT NOT NULL,
    product      VARCHAR(255) NOT NULL,
    amount_cents INT NOT NULL,
    status       VARCHAR(32) NOT NULL,
    ordered_at   TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (customer_id) REFERENCES customers(id)
);

INSERT IGNORE INTO customers (email, full_name, country) VALUES
    ('alice@example.com', 'Alice Nguyen', 'US'),
    ('bob@example.com', 'Bob Patel', 'IN'),
    ('carol@example.com', 'Carol Schmidt', 'DE'),
    ('dave@example.com', 'Dave Okonkwo', 'NG'),
    ('eve@example.com', 'Eve Tanaka', 'JP');

INSERT INTO orders (customer_id, product, amount_cents, status, ordered_at)
SELECT c.id, v.product, v.amount_cents, v.status, v.ordered_at
FROM customers c
JOIN (
    SELECT 'alice@example.com' AS email, 'Velero POC License' AS product, 4999 AS amount_cents, 'paid' AS status, DATE_SUB(NOW(), INTERVAL 2 DAY) AS ordered_at
    UNION ALL SELECT 'alice@example.com', 'Migration Support', 19900, 'paid', DATE_SUB(NOW(), INTERVAL 1 DAY)
    UNION ALL SELECT 'bob@example.com', 'Postgres Backup Addon', 1299, 'paid', DATE_SUB(NOW(), INTERVAL 5 HOUR)
    UNION ALL SELECT 'carol@example.com', 'MySQL Backup Addon', 1299, 'pending', DATE_SUB(NOW(), INTERVAL 3 HOUR)
    UNION ALL SELECT 'dave@example.com', 'Cross-cloud Egress Pack', 8900, 'paid', DATE_SUB(NOW(), INTERVAL 12 HOUR)
    UNION ALL SELECT 'eve@example.com', 'DR Runbook Template', 0, 'refunded', DATE_SUB(NOW(), INTERVAL 30 MINUTE)
) v ON c.email = v.email
WHERE NOT EXISTS (
    SELECT 1 FROM orders o
    WHERE o.customer_id = c.id AND o.product = v.product
);

SELECT 'customers' AS table_name, COUNT(*) AS row_count FROM customers
UNION ALL
SELECT 'orders', COUNT(*) FROM orders;
