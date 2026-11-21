-- ============================================================
--  PROJECT 3 (BEGINNER) : Filtering, Sorting & LIMIT
--  Topic Coverage : WHERE (AND, OR, NOT, IN, BETWEEN, LIKE, IS NULL),
--                   ORDER BY, LIMIT, OFFSET, UPDATE, DELETE
--  Tool : MySQL Workbench
--  Description : Master filtering rows and controlling result order.
--  NOTE : Run Projects 1 & 2 first.
-- ============================================================

USE CompanyDB;

-- ─────────────────────────────────────────
-- STEP 1 : WHERE with AND / OR / NOT
-- ─────────────────────────────────────────

-- AND : both conditions must be true
-- Employees in Engineering (dept 1) earning MORE than $60,000
SELECT
    CONCAT(first_name, ' ', last_name) AS 'Full Name',
    dept_id                            AS 'Dept',
    salary                             AS 'Salary'
FROM employees
WHERE dept_id = 1
  AND salary > 60000;

-- OR : at least one condition must be true
-- Employees in Finance (dept 3) OR Marketing (dept 4)
SELECT
    CONCAT(first_name, ' ', last_name) AS 'Full Name',
    dept_id                            AS 'Dept ID',
    salary                             AS 'Salary'
FROM employees
WHERE dept_id = 3
   OR dept_id = 4;

-- NOT : negates a condition
-- Employees NOT in Engineering
SELECT
    CONCAT(first_name, ' ', last_name) AS 'Full Name',
    dept_id                            AS 'Dept ID'
FROM employees
WHERE NOT dept_id = 1;

-- ─────────────────────────────────────────
-- STEP 2 : IN – match against a list of values
-- ─────────────────────────────────────────

-- Employees in departments 2, 3, or 5
-- IN is cleaner than writing multiple OR conditions
SELECT
    CONCAT(first_name, ' ', last_name) AS 'Full Name',
    dept_id                            AS 'Dept ID',
    salary                             AS 'Salary'
FROM employees
WHERE dept_id IN (2, 3, 5)
ORDER BY dept_id;

-- NOT IN – exclude a list
SELECT
    CONCAT(first_name, ' ', last_name) AS 'Full Name',
    dept_id                            AS 'Dept ID'
FROM employees
WHERE dept_id NOT IN (1, 5);

-- ─────────────────────────────────────────
-- STEP 3 : BETWEEN – range filtering (inclusive on both ends)
-- ─────────────────────────────────────────

-- Employees with salary between $50,000 and $80,000
SELECT
    CONCAT(first_name, ' ', last_name) AS 'Full Name',
    CONCAT('$', FORMAT(salary, 2))     AS 'Salary Range'
FROM employees
WHERE salary BETWEEN 50000 AND 80000
ORDER BY salary;

-- Employees hired between 2020-01-01 and 2021-12-31
SELECT
    CONCAT(first_name, ' ', last_name) AS 'Full Name',
    hire_date                          AS 'Hire Date'
FROM employees
WHERE hire_date BETWEEN '2020-01-01' AND '2021-12-31'
ORDER BY hire_date;

-- ─────────────────────────────────────────
-- STEP 4 : LIKE – pattern matching
-- ─────────────────────────────────────────

-- % matches zero or more characters
-- _ matches exactly one character

-- First names starting with 'A'
SELECT first_name, last_name FROM employees WHERE first_name LIKE 'A%';

-- Last names ending with 'son'
SELECT first_name, last_name FROM employees WHERE last_name LIKE '%son';

-- Employees whose email contains 'smith'
SELECT email FROM employees WHERE email LIKE '%smith%';

-- First names that are exactly 3 characters long
SELECT first_name FROM employees WHERE first_name LIKE '___';

-- ─────────────────────────────────────────
-- STEP 5 : IS NULL / IS NOT NULL
-- ─────────────────────────────────────────

-- Add a test employee with no title_id (NULL) to demonstrate IS NULL
INSERT INTO employees (first_name, last_name, email, hire_date, salary, dept_id)
VALUES ('Test', 'User', 'test.user@company.com', '2024-01-01', 40000, 4);

-- Find employees with NO title assigned yet
SELECT
    CONCAT(first_name, ' ', last_name) AS 'Full Name',
    title_id                           AS 'Title ID'
FROM employees
WHERE title_id IS NULL;

-- Find employees WHO HAVE a title assigned
SELECT
    CONCAT(first_name, ' ', last_name) AS 'Full Name',
    title_id                           AS 'Title ID'
FROM employees
WHERE title_id IS NOT NULL;

-- Clean up the test record
DELETE FROM employees WHERE email = 'test.user@company.com';

-- ─────────────────────────────────────────
-- STEP 6 : ORDER BY – sort results
-- ─────────────────────────────────────────

-- ASC = ascending (default, smallest → largest)
-- DESC = descending (largest → smallest)

-- All employees sorted by salary from highest to lowest
SELECT
    CONCAT(first_name, ' ', last_name) AS 'Full Name',
    salary                             AS 'Salary'
FROM employees
ORDER BY salary DESC;

-- Sort by department first, then alphabetically by last name within each dept
SELECT
    dept_id                            AS 'Dept ID',
    CONCAT(first_name, ' ', last_name) AS 'Full Name'
FROM employees
ORDER BY dept_id ASC, last_name ASC;

-- ─────────────────────────────────────────
-- STEP 7 : LIMIT & OFFSET – pagination
-- ─────────────────────────────────────────

-- Top 5 highest-paid employees
SELECT
    CONCAT(first_name, ' ', last_name) AS 'Full Name',
    CONCAT('$', FORMAT(salary, 2))     AS 'Salary'
FROM employees
ORDER BY salary DESC
LIMIT 5;

-- Pagination: get employees 6–10 (page 2, if page size = 5)
-- OFFSET tells MySQL how many rows to skip before returning results
SELECT
    CONCAT(first_name, ' ', last_name) AS 'Full Name',
    CONCAT('$', FORMAT(salary, 2))     AS 'Salary'
FROM employees
ORDER BY salary DESC
LIMIT 5 OFFSET 5;

-- ─────────────────────────────────────────
-- STEP 8 : UPDATE – modify existing rows
-- ─────────────────────────────────────────

-- Give all Engineering employees (dept_id = 1) a 10% salary raise
UPDATE employees
SET    salary = salary * 1.10
WHERE  dept_id = 1;

-- Verify the update
SELECT
    CONCAT(first_name, ' ', last_name) AS 'Full Name',
    CONCAT('$', FORMAT(salary, 2))     AS 'Updated Salary'
FROM employees
WHERE dept_id = 1;

-- Update a specific employee's mobile number
UPDATE employees
SET    mobile_number = '555-9999'
WHERE  email = 'alice.johnson@company.com';

-- ─────────────────────────────────────────
-- STEP 9 : DELETE – remove specific rows
-- ─────────────────────────────────────────

-- IMPORTANT : Always use WHERE with DELETE to avoid removing all rows!

-- First, check which rows would be deleted (run SELECT before DELETE)
SELECT emp_id, first_name, last_name, is_active
FROM   employees
WHERE  first_name = 'Eva' AND last_name = 'Davis';

-- Soft-delete: mark as inactive instead of physically removing (best practice)
UPDATE employees
SET    is_active = 0
WHERE  first_name = 'Eva' AND last_name = 'Davis';

-- Hard-delete example (commented out for safety – uncomment to test)
-- DELETE FROM employees WHERE emp_id = 5;

-- ============================================================
--  END OF PROJECT 3
--  Key concepts learned:
--   ✔ WHERE with AND, OR, NOT
--   ✔ IN, NOT IN
--   ✔ BETWEEN (for numbers and dates)
--   ✔ LIKE with % and _ wildcards
--   ✔ IS NULL / IS NOT NULL
--   ✔ ORDER BY (ASC / DESC, multi-column)
--   ✔ LIMIT and OFFSET (pagination)
--   ✔ UPDATE … SET … WHERE
--   ✔ DELETE … WHERE (and soft-delete pattern)
-- ============================================================
