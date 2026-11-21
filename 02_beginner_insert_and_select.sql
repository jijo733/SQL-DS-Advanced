-- ============================================================
--  PROJECT 2 (BEGINNER) : Data Insertion & Basic SELECT Queries
--  Topic Coverage : INSERT INTO, SELECT, Column Aliases,
--                   CONCAT, DISTINCT, WHERE basics
--  Tool : MySQL Workbench
--  Description : Populate CompanyDB with sample data and run
--  simple SELECT queries to retrieve and display it.
--  NOTE : Run Project 1 first to create the database/tables.
-- ============================================================

USE CompanyDB;

-- ─────────────────────────────────────────
-- STEP 1 : Insert data into job_titles
-- ─────────────────────────────────────────

-- INSERT multiple rows in one statement (more efficient than one row at a time)
INSERT INTO job_titles (title_name, grade_level) VALUES
    ('Intern',              1),
    ('Junior Developer',    2),
    ('Developer',           3),
    ('Senior Developer',    4),
    ('Lead Developer',      5),
    ('Engineering Manager', 6),
    ('HR Coordinator',      2),
    ('HR Manager',          5),
    ('Accountant',          3),
    ('Finance Manager',     6);

-- ─────────────────────────────────────────
-- STEP 2 : Insert data into departments
-- ─────────────────────────────────────────

INSERT INTO departments (dept_name, location) VALUES
    ('Engineering',     'Building A'),
    ('Human Resources', 'Building B'),
    ('Finance',         'Building B'),
    ('Marketing',       'Building C'),
    ('Operations',      'Head Office');

-- ─────────────────────────────────────────
-- STEP 3 : Insert data into employees
-- ─────────────────────────────────────────

-- Inserting 15 sample employees across various departments
INSERT INTO employees (first_name, last_name, email, mobile_number, hire_date, salary, dept_id, title_id) VALUES
    ('Alice',   'Johnson',  'alice.johnson@company.com',  '555-1001', '2020-01-15', 85000.00, 1, 4),
    ('Bob',     'Smith',    'bob.smith@company.com',      '555-1002', '2019-03-10', 92000.00, 1, 5),
    ('Carol',   'White',    'carol.white@company.com',    '555-1003', '2021-07-01', 65000.00, 1, 3),
    ('David',   'Brown',    'david.brown@company.com',    '555-1004', '2022-06-20', 48000.00, 1, 2),
    ('Eva',     'Davis',    'eva.davis@company.com',      '555-1005', '2023-01-10', 35000.00, 1, 1),
    ('Frank',   'Miller',   'frank.miller@company.com',   '555-1006', '2018-11-05', 110000.00,1, 6),
    ('Grace',   'Wilson',   'grace.wilson@company.com',   '555-1007', '2020-09-15', 58000.00, 2, 7),
    ('Henry',   'Moore',    'henry.moore@company.com',    '555-1008', '2017-04-22', 75000.00, 2, 8),
    ('Iris',    'Taylor',   'iris.taylor@company.com',    '555-1009', '2021-12-01', 62000.00, 3, 9),
    ('Jack',    'Anderson', 'jack.anderson@company.com',  '555-1010', '2019-08-14', 80000.00, 3, 10),
    ('Karen',   'Thomas',   'karen.thomas@company.com',   '555-1011', '2022-03-30', 55000.00, 4, 3),
    ('Leo',     'Jackson',  'leo.jackson@company.com',    '555-1012', '2020-07-19', 60000.00, 4, 3),
    ('Mia',     'Harris',   'mia.harris@company.com',     '555-1013', '2023-05-05', 45000.00, 5, 2),
    ('Nathan',  'Martin',   'nathan.martin@company.com',  '555-1014', '2018-02-28', 95000.00, 5, 5),
    ('Olivia',  'Garcia',   'olivia.garcia@company.com',  '555-1015', '2021-10-11', 70000.00, 1, 4);

-- ─────────────────────────────────────────
-- STEP 4 : Basic SELECT queries
-- ─────────────────────────────────────────

-- 4a. Select ALL columns from a table (use * sparingly – only for exploration)
SELECT * FROM departments;

-- 4b. Select specific columns only
SELECT dept_name, location FROM departments;

-- 4c. Column ALIASES – give columns a friendlier display name using AS
SELECT
    emp_id                            AS 'Employee ID',
    first_name                        AS 'First Name',
    last_name                         AS 'Last Name',
    salary                            AS 'Annual Salary (USD)'
FROM employees;

-- 4d. CONCAT – combine columns into one readable string
SELECT
    emp_id                                       AS 'ID',
    CONCAT(first_name, ' ', last_name)           AS 'Full Name',
    CONCAT('$', FORMAT(salary, 2))               AS 'Salary'
FROM employees;

-- 4e. DISTINCT – show only unique values (no duplicates)
-- How many unique locations do we have?
SELECT DISTINCT location AS 'Unique Locations' FROM departments;

-- 4f. Basic WHERE clause – filter rows
-- Show only employees in department 1 (Engineering)
SELECT
    CONCAT(first_name, ' ', last_name) AS 'Full Name',
    email                              AS 'Email',
    salary                             AS 'Salary'
FROM employees
WHERE dept_id = 1;

-- 4g. WHERE with a string comparison (case-insensitive in MySQL by default)
SELECT emp_id, first_name, last_name
FROM   employees
WHERE  first_name = 'Alice';

-- 4h. WHERE with a numeric comparison
-- Employees earning more than $70,000
SELECT
    CONCAT(first_name, ' ', last_name) AS 'Full Name',
    salary                             AS 'Annual Salary'
FROM employees
WHERE salary > 70000;

-- ─────────────────────────────────────────
-- STEP 5 : Verify row counts
-- ─────────────────────────────────────────

-- COUNT(*) returns the total number of rows in each table
SELECT 'departments' AS 'Table', COUNT(*) AS 'Total Rows' FROM departments
UNION ALL
SELECT 'employees',               COUNT(*)                  FROM employees
UNION ALL
SELECT 'job_titles',              COUNT(*)                  FROM job_titles;

-- ============================================================
--  END OF PROJECT 2
--  Key concepts learned:
--   ✔ INSERT INTO … VALUES (single & multi-row)
--   ✔ SELECT *  vs  SELECT column_list
--   ✔ Column aliases with AS
--   ✔ CONCAT() and FORMAT()
--   ✔ DISTINCT
--   ✔ WHERE with =, >, <
--   ✔ UNION ALL
-- ============================================================
