-- ============================
-- V5__demo_full_seed.sql
-- ============================

/* ---------- 0) Resolve commonly used IDs ---------- */
SET @mgr_id = (SELECT id FROM employees WHERE email='manager@example.com' LIMIT 1);

/* ---------- 1) Holidays for current year (skip if already present) ---------- */
INSERT INTO holidays (name, holiday_date, is_optional, region)
SELECT name, holiday_date, is_optional, region
FROM (
  SELECT 'New Year''s Day'  AS name, DATE(CONCAT(YEAR(CURDATE()),'-01-01')) AS holiday_date, FALSE AS is_optional, 'Global' AS region UNION ALL
  SELECT 'Republic Day',           DATE(CONCAT(YEAR(CURDATE()),'-01-26')),      FALSE,              'IN'         UNION ALL
  SELECT 'Labor Day',              DATE(CONCAT(YEAR(CURDATE()),'-05-01')),      FALSE,              'Global'     UNION ALL
  SELECT 'Independence Day',       DATE(CONCAT(YEAR(CURDATE()),'-08-15')),      FALSE,              'IN'         UNION ALL
  SELECT 'Gandhi Jayanti',         DATE(CONCAT(YEAR(CURDATE()),'-10-02')),      FALSE,              'IN'         UNION ALL
  SELECT 'Dussehra',               DATE(CONCAT(YEAR(CURDATE()),'-10-12')),      FALSE,              'IN'         UNION ALL
  SELECT 'Diwali',                 DATE(CONCAT(YEAR(CURDATE()),'-10-29')),      FALSE,              'IN'         UNION ALL
  SELECT 'Christmas',              DATE(CONCAT(YEAR(CURDATE()),'-12-25')),      FALSE,              'Global'     UNION ALL
  SELECT 'Company Retreat',        DATE(CONCAT(YEAR(CURDATE()),'-04-18')),      TRUE,               'Global'     UNION ALL
  SELECT 'Foundation Day',         DATE(CONCAT(YEAR(CURDATE()),'-07-07')),      TRUE,               'Global'
) h
WHERE NOT EXISTS (
  SELECT 1 FROM holidays x
  WHERE x.name = h.name AND x.holiday_date = h.holiday_date
);

/* ---------- 2) Leave balances for ALL employees and leave types ---------- */
/* Create any missing rows without raising duplicate warnings */
INSERT INTO leave_balances (employee_id, leave_type_id, balance_days)
SELECT e.id, lt.id,
       CASE lt.name WHEN 'Annual' THEN 15 WHEN 'Sick' THEN 8 ELSE 0 END
FROM employees e
CROSS JOIN leave_types lt
WHERE NOT EXISTS (
  SELECT 1 FROM leave_balances lb
  WHERE lb.employee_id = e.id AND lb.leave_type_id = lt.id
);

/* Normalize balances consistently (even if rows already existed) */
UPDATE leave_balances lb
JOIN leave_types lt ON lt.id = lb.leave_type_id
SET lb.balance_days = CASE lt.name WHEN 'Annual' THEN 15 WHEN 'Sick' THEN 8 ELSE 0 END;

/* ---------- 3) Sample leave requests (~150), skip if same employee & dates exist ---------- */
INSERT INTO leave_requests
  (employee_id, leave_type_id, start_date, end_date, status, reason, approver_id)
SELECT
  e.id AS employee_id,
  CASE (e.id % 3)
    WHEN 0 THEN (SELECT id FROM leave_types WHERE name='Annual' LIMIT 1)
    WHEN 1 THEN (SELECT id FROM leave_types WHERE name='Sick'   LIMIT 1)
    ELSE           (SELECT id FROM leave_types WHERE name='Unpaid' LIMIT 1)
  END AS leave_type_id,
  DATE_SUB(CURDATE(), INTERVAL ((e.id % 20) + 5) DAY) AS start_date,
  DATE_SUB(CURDATE(), INTERVAL ((e.id % 20) + 3) DAY) AS end_date,
  CASE (e.id % 4)
    WHEN 0 THEN 'PENDING'
    WHEN 1 THEN 'APPROVED'
    WHEN 2 THEN 'REJECTED'
    ELSE           'APPROVED'
  END AS status,
  'Auto-seeded demo request' AS reason,
  @mgr_id AS approver_id
FROM employees e
WHERE e.id <= LEAST(150, (SELECT COUNT(*) FROM employees))
  AND NOT EXISTS (
    SELECT 1 FROM leave_requests lr
    WHERE lr.employee_id = e.id
      AND lr.start_date = DATE_SUB(CURDATE(), INTERVAL ((e.id % 20) + 5) DAY)
      AND lr.end_date   = DATE_SUB(CURDATE(), INTERVAL ((e.id % 20) + 3) DAY)
  );

/* ---------- 4) Payslips for the last 2 complete months (first 150 employees) ---------- */
SET @m1_start = DATE_FORMAT(DATE_SUB(CURDATE(), INTERVAL 1 MONTH), '%Y-%m-01');
SET @m1_end   = LAST_DAY(@m1_start);
SET @m2_start = DATE_FORMAT(DATE_SUB(CURDATE(), INTERVAL 2 MONTH), '%Y-%m-01');
SET @m2_end   = LAST_DAY(@m2_start);

/* Month -2 (idempotent) */
INSERT INTO payslips
  (employee_id, period_start, period_end, gross_amount, net_amount, tax_amount, file_url)
SELECT
  e.id,
  @m2_start,
  @m2_end,
  60000 + (e.id % 20) * 1500        AS gross_amount,
  60000 + (e.id % 20) * 1500 - 9000 AS net_amount,
  9000                               AS tax_amount,
  CONCAT('https://files.example.com/payslips/', e.id, '_', DATE_FORMAT(@m2_end,'%Y%m'), '.pdf')
FROM employees e
WHERE e.id <= LEAST(150, (SELECT COUNT(*) FROM employees))
  AND NOT EXISTS (
    SELECT 1 FROM payslips p
    WHERE p.employee_id = e.id AND p.period_start = @m2_start AND p.period_end = @m2_end
  );

/* Month -1 (idempotent) */
INSERT INTO payslips
  (employee_id, period_start, period_end, gross_amount, net_amount, tax_amount, file_url)
SELECT
  e.id,
  @m1_start,
  @m1_end,
  60000 + (e.id % 20) * 1500 + 500  AS gross_amount,
  60000 + (e.id % 20) * 1500 - 8500 AS net_amount,
  9000                               AS tax_amount,
  CONCAT('https://files.example.com/payslips/', e.id, '_', DATE_FORMAT(@m1_end,'%Y%m'), '.pdf')
FROM employees e
WHERE e.id <= LEAST(150, (SELECT COUNT(*) FROM employees))
  AND NOT EXISTS (
    SELECT 1 FROM payslips p
    WHERE p.employee_id = e.id AND p.period_start = @m1_start AND p.period_end = @m1_end
  );

/* ---------- 5) Grievances (employees id 10..19), idempotent on (employee,title) ---------- */
INSERT INTO grievances
  (employee_id, title, description, status, handler_id)
SELECT
  e.id,
  CONCAT('Concern #', e.id) AS title,
  'Auto-seeded demo grievance' AS description,
  CASE e.id % 4 WHEN 0 THEN 'OPEN' WHEN 1 THEN 'IN_REVIEW' WHEN 2 THEN 'RESOLVED' ELSE 'DISMISSED' END AS status,
  @mgr_id AS handler_id
FROM employees e
WHERE e.id BETWEEN 10 AND 19
  AND NOT EXISTS (
    SELECT 1 FROM grievances g
    WHERE g.employee_id = e.id AND g.title = CONCAT('Concern #', e.id)
  );

/* ---------- 6) Resignations (employees id 20..25), idempotent on (employee,dates) ---------- */
INSERT INTO resignations
  (employee_id, notice_date, last_working_day, reason, status, approved_by)
SELECT
  e.id,
  DATE_SUB(CURDATE(), INTERVAL 30 DAY) AS notice_date,
  DATE_ADD(DATE_SUB(CURDATE(), INTERVAL 30 DAY), INTERVAL 60 DAY) AS last_working_day,
  'Pursuing other opportunities' AS reason,
  CASE e.id % 3 WHEN 0 THEN 'SUBMITTED' WHEN 1 THEN 'ACCEPTED' ELSE 'RETRACTED' END AS status,
  @mgr_id AS approved_by
FROM employees e
WHERE e.id BETWEEN 20 AND 25
  AND NOT EXISTS (
    SELECT 1 FROM resignations r
    WHERE r.employee_id = e.id
      AND r.notice_date = DATE_SUB(CURDATE(), INTERVAL 30 DAY)
      AND r.last_working_day = DATE_ADD(DATE_SUB(CURDATE(), INTERVAL 30 DAY), INTERVAL 60 DAY)
  );
