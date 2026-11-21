-- ============================================================
--  PROJECT 1 (BEGINNER) : Database Creation & Basic DDL
--  Topic Coverage : CREATE DATABASE, CREATE TABLE, ALTER TABLE,
--                   DROP TABLE, Data Types, Constraints
--  Tool : MySQL Workbench
--  Description : We build a small "CompanyDB" from scratch,
--  add / modify columns, and learn how to safely remove objects.
-- ============================================================

-- ─────────────────────────────────────────
-- STEP 1 : Create the database
-- ─────────────────────────────────────────

-- Drop the database first if it already exists (safe re-run)
DROP DATABASE IF EXISTS CompanyDB;

-- Create a fresh database with UTF-8 character support
CREATE DATABASE CompanyDB
    CHARACTER SET utf8mb4
    COLLATE utf8mb4_unicode_ci;

-- Tell MySQL to use this database for all following commands
USE CompanyDB;

-- ─────────────────────────────────────────
-- STEP 2 : Create tables (DDL – Data Definition Language)
-- ─────────────────────────────────────────

-- TABLE : departments
-- Stores company departments. Each department has a unique ID and name.
CREATE TABLE departments (
    dept_id     INT           NOT NULL AUTO_INCREMENT,  -- Auto-incrementing primary key
    dept_name   VARCHAR(100)  NOT NULL,                 -- Department name, cannot be empty
    location    VARCHAR(100)  DEFAULT 'Head Office',    -- Default location if not provided
    created_at  TIMESTAMP     DEFAULT CURRENT_TIMESTAMP,-- Record creation time
    PRIMARY KEY (dept_id),
    UNIQUE KEY uq_dept_name (dept_name)                 -- No duplicate department names
);

-- TABLE : employees
-- Stores employee information. Each employee belongs to one department.
CREATE TABLE employees (
    emp_id      INT            NOT NULL AUTO_INCREMENT,
    first_name  VARCHAR(50)    NOT NULL,
    last_name   VARCHAR(50)    NOT NULL,
    email       VARCHAR(150)   NOT NULL,
    phone       VARCHAR(20),                            -- Phone is optional
    hire_date   DATE           NOT NULL,
    salary      DECIMAL(10,2)  NOT NULL,                -- Salary: up to 10 digits, 2 decimal places
    dept_id     INT            NOT NULL,
    is_active   TINYINT(1)     DEFAULT 1,               -- 1 = active employee, 0 = inactive
    PRIMARY KEY (emp_id),
    UNIQUE KEY uq_email (email),
    CONSTRAINT fk_emp_dept FOREIGN KEY (dept_id)
        REFERENCES departments (dept_id)
        ON DELETE RESTRICT                              -- Prevent deleting a dept that has employees
        ON UPDATE CASCADE                               -- If dept_id changes, update here too
);

-- TABLE : job_titles
-- A lookup table for job roles in the company
CREATE TABLE job_titles (
    title_id    INT          NOT NULL AUTO_INCREMENT,
    title_name  VARCHAR(100) NOT NULL,
    grade_level TINYINT      CHECK (grade_level BETWEEN 1 AND 10), -- Grade must be 1–10
    PRIMARY KEY (title_id)
);

-- ─────────────────────────────────────────
-- STEP 3 : ALTER TABLE – modify table structure
-- ─────────────────────────────────────────

-- Add a new column to employees for their job title
ALTER TABLE employees
    ADD COLUMN title_id INT AFTER dept_id;

-- Add a foreign key constraint for the new column
ALTER TABLE employees
    ADD CONSTRAINT fk_emp_title FOREIGN KEY (title_id)
        REFERENCES job_titles (title_id)
        ON DELETE SET NULL;

-- Rename a column (MySQL 8.0+)
-- Let's rename 'phone' to 'mobile_number' for clarity
ALTER TABLE employees
    RENAME COLUMN phone TO mobile_number;

-- Modify a column's data type (increase email length for safety)
ALTER TABLE employees
    MODIFY COLUMN email VARCHAR(200) NOT NULL;

-- Add an index on hire_date to speed up date-range queries later
ALTER TABLE employees
    ADD INDEX idx_hire_date (hire_date);

-- ─────────────────────────────────────────
-- STEP 4 : View the structure of tables
-- ─────────────────────────────────────────

-- DESCRIBE shows columns, types, nullability, keys, defaults
DESCRIBE departments;
DESCRIBE employees;
DESCRIBE job_titles;

-- SHOW CREATE TABLE shows the full DDL statement MySQL generated
-- (\G is only for the MySQL command-line client; Workbench uses standard semicolons)
SHOW CREATE TABLE employees;

-- ─────────────────────────────────────────
-- STEP 5 : DROP TABLE – remove objects safely
-- ─────────────────────────────────────────

-- Create a temporary test table
CREATE TABLE temp_test (
    id   INT PRIMARY KEY,
    note VARCHAR(50)
);

-- Verify it exists
SHOW TABLES;

-- Drop the temporary table – it is gone permanently
DROP TABLE IF EXISTS temp_test;

-- Verify it is removed
SHOW TABLES;

-- ─────────────────────────────────────────
-- STEP 6 : Final output – list all tables with comments
-- ─────────────────────────────────────────

-- Show all tables in CompanyDB
SELECT table_name        AS 'Table Name',
       table_rows        AS 'Estimated Rows',
       create_time       AS 'Created At',
       table_comment     AS 'Comment'
FROM   information_schema.tables
WHERE  table_schema = 'CompanyDB'
ORDER  BY table_name;

-- ============================================================
--  END OF PROJECT 1
--  Key concepts learned:
--   ✔ CREATE DATABASE / USE
--   ✔ CREATE TABLE with data types and constraints
--   ✔ PRIMARY KEY, FOREIGN KEY, UNIQUE, DEFAULT, CHECK
--   ✔ ALTER TABLE (ADD COLUMN, RENAME COLUMN, MODIFY, ADD INDEX)
--   ✔ DROP TABLE IF EXISTS
--   ✔ DESCRIBE and SHOW CREATE TABLE
-- ============================================================
