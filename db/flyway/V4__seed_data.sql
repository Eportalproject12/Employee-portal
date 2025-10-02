/* ---------- Roles ---------- */
INSERT INTO roles (name, description)
VALUES
  ('ADMIN','System administrator'),
  ('EMPLOYEE','Regular employee')
AS new
ON DUPLICATE KEY UPDATE description = new.description;

/* ---------- Departments ---------- */
INSERT INTO departments (name)
VALUES
  ('Engineering'),
  ('Human Resources'),
  ('Finance'),
  ('Operations')
AS new
ON DUPLICATE KEY UPDATE name = new.name;

/* ---------- Leave types ---------- */
INSERT INTO leave_types (name, description, accrual_days_per_month, carry_forward, max_balance)
VALUES
  ('Annual', 'General paid time off', 1.75, TRUE, 45),
  ('Sick',   'Health-related leave',  1.00, TRUE, 30),
  ('Unpaid', 'Unpaid leave',          0.00, FALSE, NULL)
AS new
ON DUPLICATE KEY UPDATE
  description            = new.description,
  accrual_days_per_month = new.accrual_days_per_month,
  carry_forward          = new.carry_forward,
  max_balance            = new.max_balance;

/* ---------- One example holiday ---------- */
INSERT INTO holidays (name, holiday_date, is_optional, region)
VALUES ('New Year''s Day', DATE(CONCAT(YEAR(CURDATE()),'-01-01')), FALSE, 'Global')
AS new
ON DUPLICATE KEY UPDATE region = new.region;

/* ---------- Seed admin & manager employees ---------- */
INSERT INTO employees (first_name, last_name, email, department_id)
VALUES
  ('System','Admin','admin@example.com',  (SELECT id FROM departments WHERE name='Engineering')),
  ('Ava','Manager','manager@example.com', (SELECT id FROM departments WHERE name='Human Resources'))
AS new
ON DUPLICATE KEY UPDATE department_id = new.department_id;

/* ---------- Users for admin & manager (DEV hashes) ---------- */
/* admin123  => $2a$10$QH8nS6q6r9eG7K2mHq1nUeS9b6qvT3c9o6yQdN9m6Sx0B9F4y8y7a */
/* manager123=> $2a$10$QH8nS6q6r9eG7K2mHq1nUeS9b6qvT3c9o6yQdN9m6Sx0B9F4y8y7b  */
INSERT INTO users (username, email, password_hash, role_id, employee_id, is_active)
VALUES
  ('admin','admin@example.com',
     '$2a$10$QH8nS6q6r9eG7K2mHq1nUeS9b6qvT3c9o6yQdN9m6Sx0B9F4y8y7a',
     (SELECT id FROM roles WHERE name='ADMIN'),
     (SELECT id FROM employees WHERE email='admin@example.com'),
     TRUE),
  ('manager','manager@example.com',
     '$2a$10$QH8nS6q6r9eG7K2mHq1nUeS9b6qvT3c9o6yQdN9m6Sx0B9F4y8y7b',
     (SELECT id FROM roles WHERE name='EMPLOYEE'),
     (SELECT id FROM employees WHERE email='manager@example.com'),
     TRUE)
AS new
ON DUPLICATE KEY UPDATE
  role_id       = new.role_id,
  password_hash = new.password_hash,
  employee_id   = new.employee_id,
  is_active     = new.is_active;

/* ---------- Initial leave balances for admin & manager ---------- */
/* Avoid VALUES() by doing INSERT IGNORE + UPDATE */
INSERT IGNORE INTO leave_balances (employee_id, leave_type_id, balance_days)
SELECT e.id, lt.id,
       CASE lt.name WHEN 'Annual' THEN 15 WHEN 'Sick' THEN 8 ELSE 0 END
FROM employees e
JOIN users u      ON u.employee_id = e.id
JOIN leave_types lt ON lt.name IN ('Annual','Sick')
WHERE u.username IN ('admin','manager');

UPDATE leave_balances lb
JOIN users u        ON u.employee_id = lb.employee_id AND u.username IN ('admin','manager')
JOIN leave_types lt ON lt.id = lb.leave_type_id
SET lb.balance_days = CASE lt.name WHEN 'Annual' THEN 15 WHEN 'Sick' THEN 8 ELSE 0 END;

/* ---------- Bulk seed ~100 employees + matching users ---------- */

/* Cache department ids */
SET @dep_eng = (SELECT id FROM departments WHERE name='Engineering' LIMIT 1);
SET @dep_hr  = (SELECT id FROM departments WHERE name='Human Resources' LIMIT 1);
SET @dep_fin = (SELECT id FROM departments WHERE name='Finance' LIMIT 1);
SET @dep_ops = (SELECT id FROM departments WHERE name='Operations' LIMIT 1);

/* Insert 100 employees if not already present (no warnings) */
INSERT INTO employees (first_name, last_name, email, department_id)
SELECT
  CONCAT('Emp', n)                  AS first_name,
  CONCAT('User', n)                 AS last_name,
  CONCAT('emp', n, '@example.com')  AS email,
  CASE n % 4
    WHEN 0 THEN @dep_eng
    WHEN 1 THEN @dep_hr
    WHEN 2 THEN @dep_fin
    ELSE @dep_ops
  END                               AS department_id
FROM (
  SELECT ones.n + tens.n*10 + 1 AS n
  FROM
    (SELECT 0 n UNION ALL SELECT 1 UNION ALL SELECT 2 UNION ALL SELECT 3 UNION ALL SELECT 4
     UNION ALL SELECT 5 UNION ALL SELECT 6 UNION ALL SELECT 7 UNION ALL SELECT 8 UNION ALL SELECT 9) AS ones
  CROSS JOIN
    (SELECT 0 n UNION ALL SELECT 1 UNION ALL SELECT 2 UNION ALL SELECT 3 UNION ALL SELECT 4
     UNION ALL SELECT 5 UNION ALL SELECT 6 UNION ALL SELECT 7 UNION ALL SELECT 8 UNION ALL SELECT 9) AS tens
) nums
WHERE n <= 200
  AND NOT EXISTS (SELECT 1 FROM employees e2 WHERE e2.email = CONCAT('emp', n, '@example.com'));

/* Create users for any employees that don't have a user yet */
INSERT INTO users (username, email, password_hash, role_id, employee_id, is_active)
SELECT
  LOWER(SUBSTRING_INDEX(e.email,'@',1)) AS username,
  e.email,
  '$2a$10$QH8nS6q6r9eG7K2mHq1nUeS9b6qvT3c9o6yQdN9m6Sx0B9F4y8y7b' AS password_hash,
  (SELECT id FROM roles WHERE name='EMPLOYEE') AS role_id,
  e.id,
  TRUE
FROM employees e
LEFT JOIN users u ON u.employee_id = e.id
WHERE u.id IS NULL;


