-- ============================================================
--  PROJECT 10 (ADVANCED) : Indexes, Query Optimization &
--                           Advanced Analytics
--  Topic Coverage : CREATE INDEX (B-tree, composite, full-text),
--  EXPLAIN / EXPLAIN ANALYZE, query profiling, JSON columns,
--  CASE expressions, PIVOT simulation, dynamic SQL with
--  prepared statements, partitioning concepts, normalization
--  Tool : MySQL Workbench  (requires MySQL 8.0+)
--  NOTE : Run Projects 1–9 first.
-- ============================================================

USE CompanyDB;

-- ─────────────────────────────────────────
-- PART A : INDEXES
-- ─────────────────────────────────────────
-- Indexes speed up SELECT queries by creating a separate sorted
-- data structure (B-tree by default) that MySQL can search quickly,
-- similar to a book index. The trade-off: slower INSERT/UPDATE/DELETE.

-- ─────────────────────────────────────────
-- STEP 1 : View existing indexes on employees
-- ─────────────────────────────────────────

-- SHOW INDEX gives detailed info on all indexes for a table
SHOW INDEX FROM employees\G

-- ─────────────────────────────────────────
-- STEP 2 : Create single-column indexes
-- ─────────────────────────────────────────

-- Index on salary – speeds up salary range queries and ORDER BY salary
CREATE INDEX idx_salary ON employees (salary);

-- Index on last_name – speeds up WHERE last_name = … and ORDER BY last_name
CREATE INDEX idx_last_name ON employees (last_name);

-- ─────────────────────────────────────────
-- STEP 3 : Composite (multi-column) index
-- ─────────────────────────────────────────

-- A composite index on (dept_id, salary) helps queries that
-- filter by dept_id AND/OR salary in that order.
-- Rule: MySQL uses the leftmost prefix (dept_id alone also benefits).
CREATE INDEX idx_dept_salary ON employees (dept_id, salary);

-- ─────────────────────────────────────────
-- STEP 4 : FULL-TEXT index – for text search
-- ─────────────────────────────────────────

-- Full-text indexes enable fast natural-language search on text columns
-- Add a notes column to employees for demo purposes
ALTER TABLE employees ADD COLUMN notes TEXT;

UPDATE employees SET notes = 'Expert in Python, Java, and cloud architecture'      WHERE emp_id = 1;
UPDATE employees SET notes = 'Team lead with strong project management skills'      WHERE emp_id = 2;
UPDATE employees SET notes = 'Specialises in React, TypeScript and frontend design' WHERE emp_id = 3;
UPDATE employees SET notes = 'Junior developer learning Python and SQL'              WHERE emp_id = 4;
UPDATE employees SET notes = 'Intern working on machine learning and data science'   WHERE emp_id = 5;
UPDATE employees SET notes = 'Senior engineering manager, Agile and DevOps expert'  WHERE emp_id = 6;

-- Create the full-text index
CREATE FULLTEXT INDEX idx_fulltext_notes ON employees (notes);

-- MATCH … AGAINST : full-text search
-- IN NATURAL LANGUAGE MODE: standard Google-style keyword search
SELECT
    CONCAT(first_name, ' ', last_name)              AS 'Full Name',
    notes                                           AS 'Skills Notes',
    MATCH(notes) AGAINST ('Python SQL' IN NATURAL LANGUAGE MODE)
                                                    AS 'Relevance Score'
FROM employees
WHERE MATCH(notes) AGAINST ('Python SQL' IN NATURAL LANGUAGE MODE)
ORDER BY MATCH(notes) AGAINST ('Python SQL' IN NATURAL LANGUAGE MODE) DESC;

-- ─────────────────────────────────────────
-- PART B : QUERY OPTIMIZATION WITH EXPLAIN
-- ─────────────────────────────────────────
-- EXPLAIN shows MySQL's query execution plan BEFORE running it.
-- Key columns: type, key, rows, Extra
-- Best types (fastest → slowest): system, const, eq_ref, ref, range, ALL
-- 'ALL' = full table scan → usually needs an index

-- ─────────────────────────────────────────
-- STEP 5 : EXPLAIN – compare with and without index
-- ─────────────────────────────────────────

-- Query with a full table scan (no index on first_name)
EXPLAIN
SELECT * FROM employees WHERE first_name = 'Alice';

-- Query using an index (last_name IS indexed)
EXPLAIN
SELECT * FROM employees WHERE last_name = 'Johnson';

-- Query using the composite index (dept_id + salary range)
EXPLAIN
SELECT * FROM employees WHERE dept_id = 1 AND salary > 60000;

-- ─────────────────────────────────────────
-- STEP 6 : EXPLAIN ANALYZE – run + profile (MySQL 8.0.18+)
-- ─────────────────────────────────────────

-- EXPLAIN ANALYZE actually executes the query and shows real timings
EXPLAIN ANALYZE
SELECT e.first_name, e.last_name, d.dept_name
FROM   employees   e
JOIN   departments d ON e.dept_id = d.dept_id
WHERE  e.salary > 70000;

-- ─────────────────────────────────────────
-- PART C : ADVANCED CASE EXPRESSIONS
-- ─────────────────────────────────────────

-- ─────────────────────────────────────────
-- STEP 7 : CASE for column transformation
-- ─────────────────────────────────────────

-- Categorise employees by tenure and produce a matrix report
SELECT
    CONCAT(e.first_name, ' ', e.last_name)      AS 'Full Name',
    d.dept_name                                 AS 'Department',
    CONCAT('$', FORMAT(e.salary, 2))            AS 'Salary',
    -- CASE expression: classify by salary band
    CASE
        WHEN e.salary >= 90000                  THEN 'Band 4 – Executive'
        WHEN e.salary >= 70000                  THEN 'Band 3 – Senior'
        WHEN e.salary >= 50000                  THEN 'Band 2 – Mid-Level'
        ELSE                                         'Band 1 – Junior'
    END                                         AS 'Pay Band',
    -- CASE for tenure classification
    CASE
        WHEN DATEDIFF(CURDATE(), e.hire_date) > 1825 THEN 'Veteran (5+ yrs)'
        WHEN DATEDIFF(CURDATE(), e.hire_date) > 730  THEN 'Experienced (2–5 yrs)'
        ELSE                                               'New (< 2 yrs)'
    END                                         AS 'Tenure Class'
FROM       employees   e
INNER JOIN departments d ON e.dept_id = d.dept_id
WHERE e.is_active = 1
ORDER BY e.salary DESC;

-- ─────────────────────────────────────────
-- STEP 8 : PIVOT simulation (conditional aggregation)
-- ─────────────────────────────────────────

-- MySQL has no native PIVOT. We simulate it with CASE + SUM/COUNT.
-- Show head-count per pay band per department (cross-tab / pivot table)

SELECT
    d.dept_name                                                 AS 'Department',
    COUNT(CASE WHEN e.salary >= 90000                   THEN 1 END) AS 'Executive',
    COUNT(CASE WHEN e.salary >= 70000 AND e.salary < 90000 THEN 1 END) AS 'Senior',
    COUNT(CASE WHEN e.salary >= 50000 AND e.salary < 70000 THEN 1 END) AS 'Mid-Level',
    COUNT(CASE WHEN e.salary < 50000                    THEN 1 END) AS 'Junior',
    COUNT(e.emp_id)                                             AS 'Total'
FROM       departments d
LEFT JOIN  employees   e ON d.dept_id = e.dept_id AND e.is_active = 1
GROUP BY   d.dept_name
ORDER BY   d.dept_name;

-- ─────────────────────────────────────────
-- PART D : JSON DATA (MySQL 8.0+)
-- ─────────────────────────────────────────

-- ─────────────────────────────────────────
-- STEP 9 : Store and query JSON column
-- ─────────────────────────────────────────

-- Add a JSON column to store flexible employee metadata
ALTER TABLE employees ADD COLUMN metadata JSON;

-- Store structured data as JSON
UPDATE employees SET metadata = '{"skills": ["Python","SQL"], "certifications": ["AWS"], "remote": true}' WHERE emp_id = 1;
UPDATE employees SET metadata = '{"skills": ["Java","Spring"], "certifications": ["PMP"], "remote": false}' WHERE emp_id = 2;
UPDATE employees SET metadata = '{"skills": ["React","TypeScript"], "certifications": [], "remote": true}' WHERE emp_id = 3;

-- Extract values from JSON using JSON_EXTRACT (or the -> shorthand)
SELECT
    CONCAT(first_name, ' ', last_name)              AS 'Full Name',
    metadata -> '$.remote'                          AS 'Works Remotely',
    JSON_EXTRACT(metadata, '$.certifications[0]')   AS 'First Cert',
    JSON_LENGTH(metadata -> '$.skills')             AS 'Skill Count'
FROM employees
WHERE metadata IS NOT NULL;

-- JSON_CONTAINS: find employees with 'Python' in their skills array
SELECT
    CONCAT(first_name, ' ', last_name)  AS 'Full Name',
    metadata -> '$.skills'              AS 'Skills'
FROM employees
WHERE JSON_CONTAINS(metadata -> '$.skills', '"Python"');

-- JSON_ARRAYAGG: aggregate values into a JSON array
SELECT
    dept_id                                             AS 'Dept',
    JSON_ARRAYAGG(CONCAT(first_name, ' ', last_name))  AS 'Employee List'
FROM employees
WHERE is_active = 1
GROUP BY dept_id;

-- ─────────────────────────────────────────
-- PART E : PREPARED STATEMENTS (Dynamic SQL)
-- ─────────────────────────────────────────

-- ─────────────────────────────────────────
-- STEP 10 : Prepared statements
-- ─────────────────────────────────────────

-- Prepared statements compile SQL once and execute with different params.
-- Benefits: security (prevents SQL injection), performance (cached plan).

-- PREPARE: compile the query with ? as a placeholder
PREPARE stmt_emp_by_dept FROM
    'SELECT CONCAT(first_name, " ", last_name) AS "Full Name", salary
     FROM employees WHERE dept_id = ? ORDER BY salary DESC';

-- SET a variable to use as the parameter
SET @dept = 1;
EXECUTE stmt_emp_by_dept USING @dept;   -- Execute for Engineering

SET @dept = 3;
EXECUTE stmt_emp_by_dept USING @dept;   -- Execute for Finance

-- Always deallocate when done to free server memory
DEALLOCATE PREPARE stmt_emp_by_dept;

-- ─────────────────────────────────────────
-- STEP 11 : Index maintenance
-- ─────────────────────────────────────────

-- ANALYZE TABLE updates index statistics (helps optimizer make better plans)
ANALYZE TABLE employees;

-- OPTIMIZE TABLE rebuilds the table and reclaims fragmented space
OPTIMIZE TABLE employees;

-- Show final index list
SELECT
    index_name      AS 'Index Name',
    column_name     AS 'Column',
    index_type      AS 'Type',
    non_unique      AS 'Non-Unique (0=unique)'
FROM information_schema.statistics
WHERE table_schema = 'CompanyDB'
  AND table_name   = 'employees'
ORDER BY index_name;

-- ─────────────────────────────────────────
-- STEP 12 : Final comprehensive analytics report
-- ─────────────────────────────────────────

-- A single query pulling together: JOIN, CTE, window functions, CASE, aggregation
WITH employee_stats AS (
    SELECT
        e.emp_id,
        CONCAT(e.first_name, ' ', e.last_name)      AS full_name,
        d.dept_name,
        jt.title_name,
        e.salary,
        e.hire_date,
        -- Window: rank within department
        RANK() OVER (PARTITION BY e.dept_id ORDER BY e.salary DESC)
                                                    AS dept_salary_rank,
        -- Window: company-wide percentile bucket
        NTILE(100) OVER (ORDER BY e.salary ASC)     AS salary_percentile,
        -- Window: running total per department
        SUM(e.salary) OVER (PARTITION BY e.dept_id ORDER BY e.salary DESC
                            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW)
                                                    AS dept_running_total,
        -- Correlated: difference from department average
        e.salary - AVG(e.salary) OVER (PARTITION BY e.dept_id)
                                                    AS vs_dept_avg,
        -- Years of service
        FLOOR(DATEDIFF(CURDATE(), e.hire_date) / 365) AS yrs_service
    FROM       employees   e
    INNER JOIN departments d  ON e.dept_id  = d.dept_id
    LEFT  JOIN job_titles  jt ON e.title_id = jt.title_id
    WHERE e.is_active = 1
)
SELECT
    full_name                                   AS 'Employee',
    dept_name                                   AS 'Department',
    title_name                                  AS 'Job Title',
    CONCAT('$', FORMAT(salary, 2))              AS 'Salary',
    dept_salary_rank                            AS 'Rank in Dept',
    CONCAT(salary_percentile, 'th')             AS 'Company Percentile',
    CONCAT('$', FORMAT(dept_running_total, 2))  AS 'Dept Cumulative Payroll',
    CONCAT(IF(vs_dept_avg >= 0, '+', ''),
           FORMAT(vs_dept_avg, 2))              AS 'vs Dept Avg ($)',
    yrs_service                                 AS 'Years of Service',
    CASE
        WHEN salary_percentile >= 90 THEN 'Top 10%'
        WHEN salary_percentile >= 75 THEN 'Top 25%'
        WHEN salary_percentile >= 50 THEN 'Above Median'
        ELSE                               'Below Median'
    END                                         AS 'Earnings Tier'
FROM employee_stats
ORDER BY dept_name, dept_salary_rank;

-- ============================================================
--  END OF PROJECT 10
--  Key concepts learned:
--   ✔ CREATE INDEX (single, composite, full-text)
--   ✔ EXPLAIN and EXPLAIN ANALYZE (query execution plan)
--   ✔ FULLTEXT search with MATCH … AGAINST
--   ✔ Advanced CASE expressions (multi-condition classification)
--   ✔ PIVOT simulation via conditional aggregation
--   ✔ JSON column: JSON_EXTRACT, JSON_CONTAINS, JSON_ARRAYAGG, ->
--   ✔ PREPARE / EXECUTE / DEALLOCATE (prepared statements)
--   ✔ ANALYZE TABLE / OPTIMIZE TABLE
--   ✔ Comprehensive analytics: CTE + window + CASE + JOIN combined
-- ============================================================
