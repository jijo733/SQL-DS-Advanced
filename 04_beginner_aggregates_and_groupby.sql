-- ============================================================
--  PROJECT 4 (BEGINNER) : Aggregate Functions & GROUP BY
--  Topic Coverage : COUNT, SUM, AVG, MIN, MAX, GROUP BY,
--                   HAVING, ROLLUP, string/date functions
--  Tool : MySQL Workbench
--  Description : Analyse employee data using aggregation to
--  produce department-level and company-wide reports.
--  NOTE : Run Projects 1–3 first.
-- ============================================================

USE CompanyDB;

-- ─────────────────────────────────────────
-- STEP 1 : Scalar aggregate functions (entire table)
-- ─────────────────────────────────────────

-- COUNT(*) : total number of rows
SELECT COUNT(*) AS 'Total Employees' FROM employees;

-- COUNT(column) : counts non-NULL values in a column
SELECT COUNT(mobile_number) AS 'Employees With Phone' FROM employees;

-- SUM : total of all salaries
SELECT CONCAT('$', FORMAT(SUM(salary), 2)) AS 'Total Payroll' FROM employees;

-- AVG : average salary (rounded to 2 decimal places)
SELECT CONCAT('$', FORMAT(AVG(salary), 2)) AS 'Average Salary' FROM employees;

-- MIN / MAX : lowest and highest salary
SELECT
    CONCAT('$', FORMAT(MIN(salary), 2)) AS 'Lowest Salary',
    CONCAT('$', FORMAT(MAX(salary), 2)) AS 'Highest Salary'
FROM employees;

-- ─────────────────────────────────────────
-- STEP 2 : GROUP BY – aggregate per group
-- ─────────────────────────────────────────

-- Number of employees per department
-- GROUP BY splits rows into groups (one group per dept_id)
-- then COUNT(*) is applied within each group
SELECT
    dept_id             AS 'Dept ID',
    COUNT(*)            AS 'Employee Count'
FROM employees
GROUP BY dept_id
ORDER BY dept_id;

-- Payroll summary per department
SELECT
    dept_id                                      AS 'Dept ID',
    COUNT(*)                                     AS 'Head Count',
    CONCAT('$', FORMAT(SUM(salary),  2))         AS 'Total Payroll',
    CONCAT('$', FORMAT(AVG(salary),  2))         AS 'Avg Salary',
    CONCAT('$', FORMAT(MIN(salary),  2))         AS 'Min Salary',
    CONCAT('$', FORMAT(MAX(salary),  2))         AS 'Max Salary'
FROM employees
GROUP BY dept_id
ORDER BY SUM(salary) DESC;   -- Sort by highest total payroll first

-- ─────────────────────────────────────────
-- STEP 3 : HAVING – filter groups (like WHERE but for aggregates)
-- ─────────────────────────────────────────

-- WHERE filters individual rows BEFORE grouping
-- HAVING filters groups AFTER grouping

-- Departments with more than 2 employees
SELECT
    dept_id         AS 'Dept ID',
    COUNT(*)        AS 'Employee Count'
FROM employees
GROUP BY dept_id
HAVING COUNT(*) > 2;

-- Departments where the average salary exceeds $65,000
SELECT
    dept_id                                  AS 'Dept ID',
    CONCAT('$', FORMAT(AVG(salary), 2))      AS 'Avg Salary'
FROM employees
GROUP BY dept_id
HAVING AVG(salary) > 65000
ORDER BY AVG(salary) DESC;

-- Combined: WHERE + GROUP BY + HAVING
-- Among ACTIVE employees, show departments with total payroll > $100,000
SELECT
    dept_id                                  AS 'Dept ID',
    COUNT(*)                                 AS 'Active Employees',
    CONCAT('$', FORMAT(SUM(salary), 2))      AS 'Total Active Payroll'
FROM employees
WHERE  is_active = 1                         -- filter rows first
GROUP  BY dept_id
HAVING SUM(salary) > 100000                  -- then filter groups
ORDER  BY SUM(salary) DESC;

-- ─────────────────────────────────────────
-- STEP 4 : GROUP BY with ROLLUP – subtotals + grand total
-- ─────────────────────────────────────────

-- WITH ROLLUP adds an extra summary row at the end of each group
-- and a grand total row at the very end (NULL in grouping column = total)
SELECT
    IFNULL(dept_id, 'ALL DEPTS')            AS 'Dept ID',
    COUNT(*)                                AS 'Employee Count',
    CONCAT('$', FORMAT(SUM(salary), 2))     AS 'Total Payroll'
FROM employees
GROUP BY dept_id WITH ROLLUP;

-- ─────────────────────────────────────────
-- STEP 5 : Useful string & date functions
-- ─────────────────────────────────────────

-- UPPER / LOWER : change text case
SELECT UPPER(first_name) AS 'FIRST', LOWER(last_name) AS 'last' FROM employees LIMIT 5;

-- LENGTH : number of characters in a string
SELECT email, LENGTH(email) AS 'Email Length' FROM employees ORDER BY LENGTH(email) DESC LIMIT 5;

-- SUBSTRING : extract part of a string  (string, start_pos, length)
SELECT email, SUBSTRING(email, 1, LOCATE('@', email) - 1) AS 'Username' FROM employees;

-- YEAR / MONTH / DAY : extract parts from a date
SELECT
    CONCAT(first_name, ' ', last_name)  AS 'Full Name',
    hire_date                           AS 'Hire Date',
    YEAR(hire_date)                     AS 'Year',
    MONTH(hire_date)                    AS 'Month',
    DAY(hire_date)                      AS 'Day'
FROM employees;

-- DATEDIFF : number of days between two dates
-- Calculate tenure (days employed) as of today
SELECT
    CONCAT(first_name, ' ', last_name)             AS 'Full Name',
    hire_date                                      AS 'Hire Date',
    DATEDIFF(CURDATE(), hire_date)                 AS 'Days Employed',
    FLOOR(DATEDIFF(CURDATE(), hire_date) / 365)    AS 'Years Employed'
FROM employees
ORDER BY hire_date ASC;

-- CURDATE() returns today's date; NOW() returns date + time
SELECT CURDATE() AS 'Today', NOW() AS 'Right Now';

-- ─────────────────────────────────────────
-- STEP 6 : Hire cohort analysis – employees grouped by hire year
-- ─────────────────────────────────────────

SELECT
    YEAR(hire_date)                             AS 'Hire Year',
    COUNT(*)                                    AS 'New Hires',
    CONCAT('$', FORMAT(AVG(salary), 0))         AS 'Avg Starting Salary'
FROM employees
GROUP BY YEAR(hire_date)
ORDER BY YEAR(hire_date);

-- ============================================================
--  END OF PROJECT 4
--  Key concepts learned:
--   ✔ COUNT, SUM, AVG, MIN, MAX
--   ✔ GROUP BY (single and multi-column)
--   ✔ HAVING (vs WHERE)
--   ✔ GROUP BY … WITH ROLLUP
--   ✔ String functions: UPPER, LOWER, LENGTH, SUBSTRING, LOCATE
--   ✔ Date functions: YEAR, MONTH, DAY, DATEDIFF, CURDATE, NOW
--   ✔ IFNULL for handling NULLs in output
-- ============================================================
