-- ============================================================
--  PROJECT 9 (ADVANCED) : Window Functions & CTEs
--  Topic Coverage : ROW_NUMBER, RANK, DENSE_RANK, NTILE,
--  LAG, LEAD, FIRST_VALUE, LAST_VALUE, SUM/AVG OVER(),
--  PARTITION BY, ORDER BY inside OVER(),
--  Common Table Expressions (WITH … AS), recursive CTEs
--  Tool : MySQL Workbench  (requires MySQL 8.0+)
--  NOTE : Run Projects 1–8 first.
-- ============================================================

USE CompanyDB;

-- ─────────────────────────────────────────
-- WHAT ARE WINDOW FUNCTIONS?
-- Unlike GROUP BY which collapses rows into groups,
-- window functions perform calculations ACROSS a set of rows
-- that are related to the current row – without collapsing.
-- Every row stays in the output; the function just adds a new column.
-- ─────────────────────────────────────────

-- ─────────────────────────────────────────
-- STEP 1 : ROW_NUMBER() – assign a unique sequential number
-- ─────────────────────────────────────────

-- Assign a row number to each employee, ordered by salary descending
-- OVER() defines the window: ORDER BY salary DESC means rank highest first
SELECT
    ROW_NUMBER() OVER (ORDER BY salary DESC)        AS 'Overall Rank',
    CONCAT(first_name, ' ', last_name)              AS 'Full Name',
    dept_id                                         AS 'Dept',
    CONCAT('$', FORMAT(salary, 2))                  AS 'Salary'
FROM employees
WHERE is_active = 1;

-- ROW_NUMBER with PARTITION BY: restart numbering per department
SELECT
    dept_id                                                     AS 'Dept',
    CONCAT(first_name, ' ', last_name)                          AS 'Full Name',
    CONCAT('$', FORMAT(salary, 2))                              AS 'Salary',
    ROW_NUMBER() OVER (PARTITION BY dept_id ORDER BY salary DESC)
                                                                AS 'Rank In Dept'
FROM employees
WHERE is_active = 1
ORDER BY dept_id, salary DESC;

-- ─────────────────────────────────────────
-- STEP 2 : RANK() vs DENSE_RANK()
-- ─────────────────────────────────────────

-- RANK()       : ties get the same rank; next rank SKIPS numbers (1,1,3)
-- DENSE_RANK() : ties get the same rank; next rank does NOT skip (1,1,2)

SELECT
    CONCAT(first_name, ' ', last_name)                      AS 'Full Name',
    CONCAT('$', FORMAT(salary, 2))                          AS 'Salary',
    RANK()       OVER (ORDER BY salary DESC)                AS 'RANK (gaps)',
    DENSE_RANK() OVER (ORDER BY salary DESC)                AS 'DENSE_RANK (no gaps)'
FROM employees
WHERE is_active = 1
ORDER BY salary DESC;

-- ─────────────────────────────────────────
-- STEP 3 : NTILE() – divide rows into equal buckets
-- ─────────────────────────────────────────

-- Split employees into 4 salary quartiles (Q1 = lowest, Q4 = highest)
SELECT
    CONCAT(first_name, ' ', last_name)              AS 'Full Name',
    CONCAT('$', FORMAT(salary, 2))                  AS 'Salary',
    NTILE(4) OVER (ORDER BY salary ASC)             AS 'Salary Quartile'
FROM employees
WHERE is_active = 1
ORDER BY salary;

-- ─────────────────────────────────────────
-- STEP 4 : LAG() and LEAD() – access previous/next rows
-- ─────────────────────────────────────────

-- LAG(col, n)  → value from n rows BEFORE the current row
-- LEAD(col, n) → value from n rows AFTER the current row

-- Show each employee's salary alongside the person hired just before them
SELECT
    CONCAT(first_name, ' ', last_name)              AS 'Full Name',
    hire_date                                       AS 'Hire Date',
    CONCAT('$', FORMAT(salary, 2))                  AS 'My Salary',
    CONCAT('$', FORMAT(
        LAG(salary, 1) OVER (ORDER BY hire_date), 2))
                                                    AS 'Prev Hire Salary',
    CONCAT('$', FORMAT(
        LEAD(salary, 1) OVER (ORDER BY hire_date), 2))
                                                    AS 'Next Hire Salary'
FROM employees
WHERE is_active = 1
ORDER BY hire_date;

-- Year-over-year hiring count comparison using LAG
SELECT
    hire_year                               AS 'Year',
    new_hires                               AS 'New Hires',
    LAG(new_hires) OVER (ORDER BY hire_year) AS 'Prev Year Hires',
    new_hires - LAG(new_hires) OVER (ORDER BY hire_year)
                                            AS 'YoY Change'
FROM (
    SELECT YEAR(hire_date) AS hire_year, COUNT(*) AS new_hires
    FROM   employees
    GROUP  BY YEAR(hire_date)
) AS yearly_hires
ORDER BY hire_year;

-- ─────────────────────────────────────────
-- STEP 5 : Running totals and moving averages
-- ─────────────────────────────────────────

-- Running (cumulative) payroll total, ordered by hire date
SELECT
    CONCAT(first_name, ' ', last_name)              AS 'Full Name',
    hire_date                                       AS 'Hire Date',
    CONCAT('$', FORMAT(salary, 2))                  AS 'Salary',
    CONCAT('$', FORMAT(
        SUM(salary) OVER (ORDER BY hire_date
                          ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW), 2))
                                                    AS 'Running Payroll Total'
FROM employees
WHERE is_active = 1
ORDER BY hire_date;

-- 3-row moving average of salary (centered on current row)
SELECT
    CONCAT(first_name, ' ', last_name)              AS 'Full Name',
    CONCAT('$', FORMAT(salary, 2))                  AS 'Salary',
    CONCAT('$', FORMAT(
        AVG(salary) OVER (ORDER BY salary
                          ROWS BETWEEN 1 PRECEDING AND 1 FOLLOWING), 2))
                                                    AS '3-Row Moving Avg'
FROM employees
WHERE is_active = 1
ORDER BY salary;

-- ─────────────────────────────────────────
-- STEP 6 : FIRST_VALUE() and LAST_VALUE() per partition
-- ─────────────────────────────────────────

-- Highest and lowest salary in each department (shown on every row)
SELECT
    dept_id                                                     AS 'Dept',
    CONCAT(first_name, ' ', last_name)                          AS 'Full Name',
    CONCAT('$', FORMAT(salary, 2))                              AS 'Salary',
    CONCAT('$', FORMAT(
        FIRST_VALUE(salary) OVER (PARTITION BY dept_id ORDER BY salary DESC), 2))
                                                                AS 'Dept Max Salary',
    CONCAT('$', FORMAT(
        LAST_VALUE(salary) OVER (
            PARTITION BY dept_id ORDER BY salary DESC
            RANGE BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING), 2))
                                                                AS 'Dept Min Salary'
FROM employees
WHERE is_active = 1
ORDER BY dept_id, salary DESC;

-- ─────────────────────────────────────────
-- PART B : COMMON TABLE EXPRESSIONS (CTEs)
-- ─────────────────────────────────────────
-- A CTE (WITH clause) names a temporary result set you can reference
-- in the main query. Cleaner and more readable than derived tables.

-- ─────────────────────────────────────────
-- STEP 7 : Simple CTE
-- ─────────────────────────────────────────

-- CTE to find employees above company average salary
WITH above_avg_cte AS (
    -- This block runs first and is named 'above_avg_cte'
    SELECT
        emp_id, first_name, last_name, salary, dept_id
    FROM employees
    WHERE salary > (SELECT AVG(salary) FROM employees)
      AND is_active = 1
)
-- Main query references the CTE by name
SELECT
    CONCAT(a.first_name, ' ', a.last_name)  AS 'High Earner',
    d.dept_name                             AS 'Department',
    CONCAT('$', FORMAT(a.salary, 2))        AS 'Salary'
FROM above_avg_cte a
INNER JOIN departments d ON a.dept_id = d.dept_id
ORDER BY a.salary DESC;

-- ─────────────────────────────────────────
-- STEP 8 : Multiple CTEs chained together
-- ─────────────────────────────────────────

-- Step 1 CTE: department salary stats
-- Step 2 CTE: grade each department
-- Main query: combine and display
WITH dept_stats AS (
    SELECT
        dept_id,
        COUNT(*)        AS head_count,
        AVG(salary)     AS avg_salary,
        SUM(salary)     AS total_payroll
    FROM employees
    WHERE is_active = 1
    GROUP BY dept_id
),
dept_graded AS (
    SELECT
        ds.*,
        CASE
            WHEN avg_salary >= 80000 THEN 'Premium'
            WHEN avg_salary >= 60000 THEN 'Standard'
            ELSE                          'Budget'
        END AS payroll_grade
    FROM dept_stats ds
)
SELECT
    d.dept_name                                 AS 'Department',
    dg.head_count                               AS 'Employees',
    CONCAT('$', FORMAT(dg.avg_salary, 2))       AS 'Avg Salary',
    CONCAT('$', FORMAT(dg.total_payroll, 2))    AS 'Total Payroll',
    dg.payroll_grade                            AS 'Grade'
FROM dept_graded dg
INNER JOIN departments d ON dg.dept_id = d.dept_id
ORDER BY dg.total_payroll DESC;

-- ─────────────────────────────────────────
-- STEP 9 : Recursive CTE – generate a number series
-- ─────────────────────────────────────────

-- Recursive CTEs call themselves to build hierarchical or serial data.
-- Syntax: WITH RECURSIVE name AS (anchor UNION ALL recursive_part)

-- Generate numbers 1 to 12 (month numbers)
WITH RECURSIVE month_series AS (
    SELECT 1 AS month_num           -- Anchor: start with 1
    UNION ALL
    SELECT month_num + 1            -- Recursive: add 1 each iteration
    FROM   month_series
    WHERE  month_num < 12           -- Stop condition: stop at 12
)
SELECT
    month_num                                           AS 'Month #',
    MONTHNAME(STR_TO_DATE(month_num, '%m'))             AS 'Month Name'
FROM month_series;

-- ─────────────────────────────────────────
-- STEP 10 : Recursive CTE – employee org chart (manager hierarchy)
-- ─────────────────────────────────────────

WITH RECURSIVE org_chart AS (
    -- Anchor: top-level employees (no manager)
    SELECT
        emp_id,
        CONCAT(first_name, ' ', last_name)  AS employee_name,
        manager_id,
        1                                   AS depth,          -- level in hierarchy
        CAST(CONCAT(first_name, ' ', last_name) AS CHAR(500)) AS hierarchy_path
    FROM employees
    WHERE manager_id IS NULL

    UNION ALL

    -- Recursive: find direct reports of each manager found so far
    SELECT
        e.emp_id,
        CONCAT(e.first_name, ' ', e.last_name),
        e.manager_id,
        oc.depth + 1,
        CONCAT(oc.hierarchy_path, ' → ', e.first_name, ' ', e.last_name)
    FROM employees e
    INNER JOIN org_chart oc ON e.manager_id = oc.emp_id
    WHERE oc.depth < 5   -- safety: max 5 levels deep to prevent infinite loops
)
SELECT
    LPAD('', (depth - 1) * 4, ' ')             -- indent by level
        || employee_name                        AS 'Org Chart',
    depth                                       AS 'Level',
    hierarchy_path                              AS 'Full Path'
FROM org_chart
ORDER BY hierarchy_path;

-- ============================================================
--  END OF PROJECT 9
--  Key concepts learned:
--   ✔ Window functions overview (no GROUP BY collapse)
--   ✔ ROW_NUMBER(), RANK(), DENSE_RANK(), NTILE()
--   ✔ PARTITION BY – restart window per group
--   ✔ LAG() and LEAD() – previous/next row access
--   ✔ Running totals: SUM() OVER (ROWS BETWEEN … AND …)
--   ✔ Moving average with ROWS frame
--   ✔ FIRST_VALUE() and LAST_VALUE()
--   ✔ WITH … AS (CTE) – simple and chained
--   ✔ WITH RECURSIVE – serial data and org-chart hierarchy
-- ============================================================
