-- ============================================================
--  PROJECT 6 (INTERMEDIATE) : Subqueries & Views
--  Topic Coverage : Scalar subquery, row subquery, correlated
--  subquery, EXISTS / NOT EXISTS, IN subquery, derived table,
--  CREATE VIEW, updatable views, WITH CHECK OPTION
--  Tool : MySQL Workbench
--  NOTE : Run Projects 1–5 first.
-- ============================================================

USE CompanyDB;

-- ─────────────────────────────────────────
-- PART A : SUBQUERIES
-- ─────────────────────────────────────────
-- A subquery is a SELECT statement nested inside another SQL statement.
-- It is evaluated first, and its result is passed to the outer query.

-- ─────────────────────────────────────────
-- STEP 1 : Scalar subquery – returns a single value
-- ─────────────────────────────────────────

-- Find employees who earn MORE than the company average salary
-- The inner query calculates one number; the outer query uses it
SELECT
    CONCAT(first_name, ' ', last_name)  AS 'Full Name',
    CONCAT('$', FORMAT(salary, 2))      AS 'Salary',
    CONCAT('$', FORMAT(
        (SELECT AVG(salary) FROM employees), 2
    ))                                  AS 'Company Avg'
FROM employees
WHERE salary > (SELECT AVG(salary) FROM employees)
ORDER BY salary DESC;

-- ─────────────────────────────────────────
-- STEP 2 : Subquery with IN – returns a list
-- ─────────────────────────────────────────

-- Find employees who work in departments located in 'Building A' or 'Building B'
-- Step 1 (inner): get dept_ids for those locations
-- Step 2 (outer): find employees in those dept_ids
SELECT
    CONCAT(first_name, ' ', last_name)  AS 'Full Name',
    dept_id                             AS 'Dept ID'
FROM employees
WHERE dept_id IN (
    SELECT dept_id
    FROM   departments
    WHERE  location IN ('Building A', 'Building B')
);

-- ─────────────────────────────────────────
-- STEP 3 : Correlated subquery – references the outer query
-- ─────────────────────────────────────────

-- A correlated subquery runs ONCE PER ROW of the outer query.
-- It uses a column from the outer query (e.dept_id here).

-- For each employee, show whether they earn above their own department's average
SELECT
    CONCAT(e.first_name, ' ', e.last_name)          AS 'Full Name',
    e.dept_id                                       AS 'Dept',
    CONCAT('$', FORMAT(e.salary, 2))                AS 'My Salary',
    CONCAT('$', FORMAT(
        (SELECT AVG(salary) FROM employees sub WHERE sub.dept_id = e.dept_id), 2
    ))                                              AS 'Dept Avg',
    CASE
        WHEN e.salary > (SELECT AVG(salary) FROM employees sub WHERE sub.dept_id = e.dept_id)
        THEN '▲ Above Average'
        ELSE '▼ At or Below Average'
    END                                             AS 'Status'
FROM employees e
ORDER BY e.dept_id, e.salary DESC;

-- ─────────────────────────────────────────
-- STEP 4 : EXISTS / NOT EXISTS
-- ─────────────────────────────────────────

-- EXISTS returns TRUE if the subquery returns at least one row
-- It is often faster than IN for large datasets

-- Departments that HAVE at least one employee
SELECT dept_name AS 'Active Department'
FROM   departments d
WHERE  EXISTS (
    SELECT 1
    FROM   employees e
    WHERE  e.dept_id = d.dept_id
);

-- Departments with NO employees at all
SELECT dept_name AS 'Empty Department'
FROM   departments d
WHERE  NOT EXISTS (
    SELECT 1
    FROM   employees e
    WHERE  e.dept_id = d.dept_id
);

-- ─────────────────────────────────────────
-- STEP 5 : Derived table (subquery in FROM clause)
-- ─────────────────────────────────────────

-- A derived table is a subquery used as a temporary table in FROM.
-- MySQL requires it to have an alias.

-- Find the top earner per department using a derived table
SELECT
    dept_summary.dept_id                            AS 'Dept ID',
    d.dept_name                                     AS 'Department',
    CONCAT(e.first_name, ' ', e.last_name)          AS 'Top Earner',
    CONCAT('$', FORMAT(dept_summary.max_salary, 2)) AS 'Max Salary'
FROM (
    -- Inner query: find the max salary per department
    SELECT dept_id, MAX(salary) AS max_salary
    FROM   employees
    GROUP  BY dept_id
) AS dept_summary                                   -- alias is mandatory for derived tables
INNER JOIN employees   e ON e.dept_id = dept_summary.dept_id
                        AND e.salary  = dept_summary.max_salary
INNER JOIN departments d ON d.dept_id = dept_summary.dept_id
ORDER BY dept_summary.max_salary DESC;

-- ─────────────────────────────────────────
-- PART B : VIEWS
-- ─────────────────────────────────────────
-- A VIEW is a stored SELECT query with a name.
-- It looks like a table but always shows live data.
-- Benefits: simplify complex queries, hide sensitive columns, reuse logic

-- ─────────────────────────────────────────
-- STEP 6 : Create a simple view
-- ─────────────────────────────────────────

-- View: employee directory (hides salary by default)
CREATE OR REPLACE VIEW vw_employee_directory AS
SELECT
    e.emp_id                                    AS emp_id,
    CONCAT(e.first_name, ' ', e.last_name)      AS full_name,
    e.email                                     AS email,
    e.mobile_number                             AS mobile,
    d.dept_name                                 AS department,
    jt.title_name                               AS job_title,
    e.hire_date                                 AS hire_date,
    e.is_active                                 AS is_active
FROM       employees   e
INNER JOIN departments d  ON e.dept_id  = d.dept_id
LEFT  JOIN job_titles  jt ON e.title_id = jt.title_id;

-- Query the view just like a table
SELECT * FROM vw_employee_directory WHERE is_active = 1 ORDER BY department, full_name;

-- ─────────────────────────────────────────
-- STEP 7 : Aggregate view
-- ─────────────────────────────────────────

-- View: department payroll summary
CREATE OR REPLACE VIEW vw_dept_payroll_summary AS
SELECT
    d.dept_id                                   AS dept_id,
    d.dept_name                                 AS department,
    d.location                                  AS location,
    COUNT(e.emp_id)                             AS head_count,
    ROUND(AVG(e.salary), 2)                     AS avg_salary,
    SUM(e.salary)                               AS total_payroll,
    MIN(e.salary)                               AS min_salary,
    MAX(e.salary)                               AS max_salary
FROM       departments d
LEFT JOIN  employees   e ON d.dept_id = e.dept_id AND e.is_active = 1
GROUP BY   d.dept_id, d.dept_name, d.location;

-- Query the payroll summary view
SELECT
    department                          AS 'Department',
    location                            AS 'Location',
    head_count                          AS 'Employees',
    CONCAT('$', FORMAT(avg_salary, 2))  AS 'Avg Salary',
    CONCAT('$', FORMAT(total_payroll, 2)) AS 'Total Payroll'
FROM vw_dept_payroll_summary
ORDER BY total_payroll DESC;

-- ─────────────────────────────────────────
-- STEP 8 : View for above-average earners
-- ─────────────────────────────────────────

CREATE OR REPLACE VIEW vw_high_earners AS
SELECT
    e.emp_id,
    CONCAT(e.first_name, ' ', e.last_name)  AS full_name,
    d.dept_name                             AS department,
    e.salary
FROM       employees   e
INNER JOIN departments d ON e.dept_id = d.dept_id
WHERE e.salary > (SELECT AVG(salary) FROM employees);

-- Query the view
SELECT full_name AS 'High Earner', department AS 'Dept',
       CONCAT('$', FORMAT(salary, 2)) AS 'Salary'
FROM   vw_high_earners
ORDER  BY salary DESC;

-- ─────────────────────────────────────────
-- STEP 9 : List all views in the database
-- ─────────────────────────────────────────

SELECT table_name AS 'View Name'
FROM   information_schema.views
WHERE  table_schema = 'CompanyDB';

-- ─────────────────────────────────────────
-- STEP 10 : Drop a view
-- ─────────────────────────────────────────

-- DROP VIEW removes the view definition only – NOT the underlying data
DROP VIEW IF EXISTS vw_high_earners;

-- Re-check views list
SELECT table_name AS 'Remaining Views'
FROM   information_schema.views
WHERE  table_schema = 'CompanyDB';

-- ============================================================
--  END OF PROJECT 6
--  Key concepts learned:
--   ✔ Scalar subquery (single value)
--   ✔ Subquery with IN (list of values)
--   ✔ Correlated subquery (row-by-row reference to outer query)
--   ✔ EXISTS / NOT EXISTS
--   ✔ Derived table (subquery in FROM clause)
--   ✔ CREATE OR REPLACE VIEW
--   ✔ Querying views like tables
--   ✔ Aggregate views
--   ✔ DROP VIEW
-- ============================================================
