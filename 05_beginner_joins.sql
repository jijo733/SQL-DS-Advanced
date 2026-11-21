-- ============================================================
--  PROJECT 5 (BEGINNER) : JOINs – Combining Multiple Tables
--  Topic Coverage : INNER JOIN, LEFT JOIN, RIGHT JOIN,
--                   CROSS JOIN, self-join, multi-table join
--  Tool : MySQL Workbench
--  Description : Learn how to combine data from departments,
--  employees, and job_titles into meaningful reports.
--  NOTE : Run Projects 1–4 first.
-- ============================================================

USE CompanyDB;

-- ─────────────────────────────────────────
-- Quick data check before joining
-- ─────────────────────────────────────────

-- Always understand what is in each table before joining
SELECT COUNT(*) AS 'employees rows'   FROM employees;
SELECT COUNT(*) AS 'departments rows' FROM departments;
SELECT COUNT(*) AS 'job_titles rows'  FROM job_titles;

-- ─────────────────────────────────────────
-- STEP 1 : INNER JOIN – only matching rows from BOTH tables
-- ─────────────────────────────────────────

-- Combine employees with their department names
-- INNER JOIN returns rows where dept_id exists in BOTH tables
-- Employees with no matching department are excluded
SELECT
    e.emp_id                                AS 'ID',
    CONCAT(e.first_name, ' ', e.last_name)  AS 'Full Name',
    d.dept_name                             AS 'Department',
    d.location                              AS 'Location',
    CONCAT('$', FORMAT(e.salary, 2))        AS 'Salary'
FROM employees  e          -- alias 'e' for employees table
INNER JOIN departments d   -- alias 'd' for departments table
    ON e.dept_id = d.dept_id
ORDER BY d.dept_name, e.last_name;

-- ─────────────────────────────────────────
-- STEP 2 : Three-table JOIN
-- ─────────────────────────────────────────

-- Combine employees + departments + job_titles in one query
SELECT
    e.emp_id                                AS 'ID',
    CONCAT(e.first_name, ' ', e.last_name)  AS 'Full Name',
    d.dept_name                             AS 'Department',
    jt.title_name                           AS 'Job Title',
    jt.grade_level                          AS 'Grade',
    CONCAT('$', FORMAT(e.salary, 2))        AS 'Salary',
    e.hire_date                             AS 'Hire Date'
FROM       employees   e
INNER JOIN departments d  ON e.dept_id  = d.dept_id
INNER JOIN job_titles  jt ON e.title_id = jt.title_id
ORDER BY d.dept_name, jt.grade_level DESC;

-- ─────────────────────────────────────────
-- STEP 3 : LEFT JOIN – all rows from the LEFT table,
--          matching rows from the RIGHT (NULLs if no match)
-- ─────────────────────────────────────────

-- Show ALL employees, even those without a job title assigned
SELECT
    CONCAT(e.first_name, ' ', e.last_name)      AS 'Full Name',
    COALESCE(jt.title_name, 'No Title Assigned') AS 'Job Title'
FROM       employees  e
LEFT JOIN  job_titles jt ON e.title_id = jt.title_id
ORDER BY jt.title_name;

-- Show ALL departments, even those with zero employees
SELECT
    d.dept_name                             AS 'Department',
    d.location                              AS 'Location',
    COUNT(e.emp_id)                         AS 'Employee Count'
FROM       departments d
LEFT JOIN  employees   e ON d.dept_id = e.dept_id
GROUP BY   d.dept_id, d.dept_name, d.location
ORDER BY   COUNT(e.emp_id) DESC;

-- ─────────────────────────────────────────
-- STEP 4 : RIGHT JOIN – all rows from the RIGHT table,
--          matching rows from the LEFT (NULLs if no match)
-- ─────────────────────────────────────────

-- Show ALL job_titles, including those not yet assigned to any employee
SELECT
    jt.title_name                               AS 'Job Title',
    jt.grade_level                              AS 'Grade',
    COALESCE(CONCAT(e.first_name, ' ', e.last_name), 'Unassigned')
                                                AS 'Employee'
FROM       employees  e
RIGHT JOIN job_titles jt ON e.title_id = jt.title_id
ORDER BY   jt.grade_level, e.last_name;

-- ─────────────────────────────────────────
-- STEP 5 : Find records with NO match (anti-join pattern)
-- ─────────────────────────────────────────

-- Job titles that have NO employees assigned
-- Combine LEFT/RIGHT JOIN with IS NULL to find orphans
SELECT
    jt.title_id   AS 'Title ID',
    jt.title_name AS 'Unassigned Job Title'
FROM       job_titles jt
LEFT JOIN  employees  e ON jt.title_id = e.title_id
WHERE      e.emp_id IS NULL;             -- NULL means no match was found

-- ─────────────────────────────────────────
-- STEP 6 : CROSS JOIN – every combination of two tables
-- ─────────────────────────────────────────

-- CROSS JOIN produces M × N rows (cartesian product)
-- Useful for generating combination matrices
-- Example: list every possible dept-location combination
SELECT
    d.dept_name  AS 'Department',
    l.location   AS 'Possible Location'
FROM (SELECT DISTINCT location FROM departments) l
CROSS JOIN departments d
ORDER BY d.dept_name, l.location
LIMIT 20;   -- Limit output to avoid flooding workbench

-- ─────────────────────────────────────────
-- STEP 7 : Self JOIN – join a table to itself
-- ─────────────────────────────────────────

-- Add a manager_id column to employees to demonstrate self-join
ALTER TABLE employees ADD COLUMN manager_id INT DEFAULT NULL;

-- Assign some managers (emp_id 6 = Frank Miller manages Engineering dept)
UPDATE employees SET manager_id = 6 WHERE dept_id = 1 AND emp_id <> 6;
UPDATE employees SET manager_id = 8 WHERE dept_id = 2 AND emp_id <> 8;

-- Self-JOIN: show each employee alongside their manager's name
-- Both 'e' (employee) and 'm' (manager) reference the SAME table
SELECT
    CONCAT(e.first_name, ' ', e.last_name)  AS 'Employee',
    COALESCE(
        CONCAT(m.first_name, ' ', m.last_name),
        'Top Level / No Manager')            AS 'Reports To'
FROM       employees e
LEFT JOIN  employees m ON e.manager_id = m.emp_id
ORDER BY   e.dept_id, e.last_name;

-- ─────────────────────────────────────────
-- STEP 8 : Practical JOIN report – Department Directory
-- ─────────────────────────────────────────

SELECT
    d.dept_name                             AS 'Department',
    d.location                              AS 'Location',
    CONCAT(e.first_name, ' ', e.last_name)  AS 'Employee',
    jt.title_name                           AS 'Job Title',
    CONCAT('$', FORMAT(e.salary, 2))        AS 'Salary',
    e.hire_date                             AS 'Hire Date'
FROM       departments d
LEFT JOIN  employees   e  ON d.dept_id  = e.dept_id
LEFT JOIN  job_titles  jt ON e.title_id = jt.title_id
WHERE      e.is_active = 1
ORDER BY   d.dept_name, jt.grade_level DESC, e.last_name;

-- ============================================================
--  END OF PROJECT 5
--  Key concepts learned:
--   ✔ INNER JOIN (only matching rows)
--   ✔ LEFT JOIN (all from left + matches from right)
--   ✔ RIGHT JOIN (all from right + matches from left)
--   ✔ Anti-join pattern (LEFT JOIN + IS NULL)
--   ✔ CROSS JOIN (cartesian product)
--   ✔ Self-JOIN (table joined to itself)
--   ✔ Multi-table (3-way) JOIN
--   ✔ Table aliases (e, d, jt, m)
--   ✔ COALESCE() for replacing NULLs in output
-- ============================================================
