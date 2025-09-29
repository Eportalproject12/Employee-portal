-- Roles
INSERT INTO roles (name, description) VALUES
  ('ADMIN','System administrator'),
  ('EMPLOYEE','Regular employee')
ON DUPLICATE KEY UPDATE description=VALUES(description);

-- Departments
INSERT INTO departments (name) VALUES
  ('Engineering'), ('Human Resources'), ('Finance'), ('Operations')
ON DUPLICATE KEY UPDATE name=VALUES(name);

-- Leave types
INSERT INTO leave_types (name, description, accrual_days_per_month, carry_forward, max_balance) VALUES
  ('Annual', 'General paid time off', 1.75, TRUE, 45),
  ('Sick', 'Health-related leave', 1.00, TRUE, 30),
  ('Unpaid', 'Unpaid leave', 0.00, FALSE, NULL)
ON DUPLICATE KEY UPDATE description=VALUES(description);

-- Holidays (example; adjust to your region)
INSERT INTO holidays (name, holiday_date, is_optional, region) VALUES
  ('New Year''s Day', DATE(CONCAT(YEAR(CURDATE()),'-01-01')), FALSE, 'Global')
ON DUPLICATE KEY UPDATE region=VALUES(region);

-- Seed two employees
INSERT INTO employees (first_name, last_name, email, department_id) VALUES
  ('System','Admin','admin@example.com', (SELECT id FROM departments WHERE name='Engineering')),
  ('Ava','Manager','manager@example.com', (SELECT id FROM departments WHERE name='Human Resources'))
ON DUPLICATE KEY UPDATE department_id=VALUES(department_id);

-- DEV-ONLY: bcrypt hashes (placeholders). Replace with real hashes before sharing!
-- admin123  => $2a$10$QH8nS6q6r9eG7K2mHq1nUeS9b6qvT3c9o6yQdN9m6Sx0B9F4y8y7a
-- manager123=> $2a$10$QH8nS6q6r9eG7K2mHq1nUeS9b6qvT3c9o6yQdN9m6Sx0B9F4y8y7b

INSERT INTO users (username, email, password_hash, role_id, employee_id, is_active) VALUES
  ('admin','admin@example.com',  '$2a$10$QH8nS6q6r9eG7K2mHq1nUeS9b6qvT3c9o6yQdN9m6Sx0B9F4y8y7a',
     (SELECT id FROM roles WHERE name='ADMIN'),    (SELECT id FROM employees WHERE email='admin@example.com'),    TRUE),
  ('manager','manager@example.com','$2a$10$QH8nS6q6r9eG7K2mHq1nUeS9b6qvT3c9o6yQdN9m6Sx0B9F4y8y7b',
     (SELECT id FROM roles WHERE name='EMPLOYEE'), (SELECT id FROM employees WHERE email='manager@example.com'), TRUE)
ON DUPLICATE KEY UPDATE role_id=VALUES(role_id);

-- Initial leave balances
INSERT INTO leave_balances (employee_id, leave_type_id, balance_days)
SELECT e.id, lt.id,
       CASE lt.name WHEN 'Annual' THEN 15 WHEN 'Sick' THEN 8 ELSE 0 END
FROM employees e
JOIN users u ON u.employee_id = e.id
JOIN leave_types lt ON lt.name IN ('Annual','Sick')
WHERE u.username IN ('admin','manager')
ON DUPLICATE KEY UPDATE balance_days=VALUES(balance_days);
