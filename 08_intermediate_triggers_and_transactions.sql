-- ============================================================
--  PROJECT 8 (INTERMEDIATE) : Triggers & Transactions
--  Topic Coverage : BEFORE/AFTER INSERT/UPDATE/DELETE triggers,
--  NEW/OLD pseudo-rows, audit logging, TRANSACTION, COMMIT,
--  ROLLBACK, SAVEPOINT, LOCK TABLES, error handling
--  Tool : MySQL Workbench
--  NOTE : Run Projects 1–7 first.
-- ============================================================

USE CompanyDB;

-- ─────────────────────────────────────────
-- PART A : TRIGGERS
-- ─────────────────────────────────────────
-- A TRIGGER is code that runs automatically when a DML event
-- (INSERT, UPDATE, DELETE) happens on a specified table.

-- ─────────────────────────────────────────
-- STEP 1 : Create an audit log table
-- ─────────────────────────────────────────

-- This table records every salary change for compliance/history
CREATE TABLE IF NOT EXISTS salary_audit_log (
    log_id       INT           NOT NULL AUTO_INCREMENT,
    emp_id       INT           NOT NULL,
    changed_by   VARCHAR(100)  DEFAULT (USER()),  -- who made the change
    change_time  TIMESTAMP     DEFAULT CURRENT_TIMESTAMP,
    old_salary   DECIMAL(10,2),
    new_salary   DECIMAL(10,2),
    change_pct   DECIMAL(5,2),                    -- percentage change
    action_type  VARCHAR(10),                     -- 'INSERT', 'UPDATE', 'DELETE'
    PRIMARY KEY (log_id)
);

-- General employee activity log
CREATE TABLE IF NOT EXISTS employee_activity_log (
    log_id      INT           NOT NULL AUTO_INCREMENT,
    action      VARCHAR(20)   NOT NULL,            -- 'HIRED', 'TERMINATED', etc.
    emp_id      INT           NOT NULL,
    details     VARCHAR(300),
    logged_at   TIMESTAMP     DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (log_id)
);

-- ─────────────────────────────────────────
-- STEP 2 : AFTER INSERT trigger – log new hires
-- ─────────────────────────────────────────

DELIMITER $$

-- Fires AFTER a new row is inserted into employees
-- NEW.column_name refers to the values just inserted
CREATE TRIGGER trg_after_employee_insert
AFTER INSERT ON employees
FOR EACH ROW
BEGIN
    INSERT INTO employee_activity_log (action, emp_id, details)
    VALUES (
        'HIRED',
        NEW.emp_id,
        CONCAT('New hire: ', NEW.first_name, ' ', NEW.last_name,
               ' | Dept: ', NEW.dept_id,
               ' | Starting salary: $', FORMAT(NEW.salary, 2))
    );

    -- Also log the starting salary in the salary audit log
    INSERT INTO salary_audit_log (emp_id, old_salary, new_salary, change_pct, action_type)
    VALUES (NEW.emp_id, NULL, NEW.salary, NULL, 'INSERT');
END $$

DELIMITER ;

-- Test the INSERT trigger by adding a new employee
INSERT INTO employees (first_name, last_name, email, hire_date, salary, dept_id, title_id)
VALUES ('Sophie', 'Clark', 'sophie.clark@company.com', CURDATE(), 55000, 3, 9);

-- Verify the log was created
SELECT * FROM employee_activity_log ORDER BY logged_at DESC LIMIT 5;
SELECT * FROM salary_audit_log      ORDER BY log_id    DESC LIMIT 5;

-- ─────────────────────────────────────────
-- STEP 3 : BEFORE UPDATE trigger – validate and log salary changes
-- ─────────────────────────────────────────

DELIMITER $$

-- Fires BEFORE an UPDATE on employees
-- BEFORE triggers can modify NEW.column values (validation / correction)
-- OLD.column_name = value before the update
-- NEW.column_name = value that WILL be saved (can be changed in BEFORE trigger)
CREATE TRIGGER trg_before_employee_update
BEFORE UPDATE ON employees
FOR EACH ROW
BEGIN
    -- Business rule: salary cannot be reduced by more than 20%
    IF NEW.salary < OLD.salary * 0.80 THEN
        -- Signal an error to abort the update
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Salary reduction of more than 20% is not allowed.';
    END IF;

    -- Business rule: salary cannot exceed $300,000
    IF NEW.salary > 300000 THEN
        SET NEW.salary = 300000;   -- Cap it silently
    END IF;
END $$

DELIMITER ;

-- ─────────────────────────────────────────
-- STEP 4 : AFTER UPDATE trigger – record salary changes in audit log
-- ─────────────────────────────────────────

DELIMITER $$

CREATE TRIGGER trg_after_employee_update
AFTER UPDATE ON employees
FOR EACH ROW
BEGIN
    -- Only log if the salary actually changed
    IF OLD.salary <> NEW.salary THEN
        INSERT INTO salary_audit_log (emp_id, old_salary, new_salary, change_pct, action_type)
        VALUES (
            NEW.emp_id,
            OLD.salary,
            NEW.salary,
            ROUND(((NEW.salary - OLD.salary) / OLD.salary) * 100, 2),
            'UPDATE'
        );
    END IF;
END $$

DELIMITER ;

-- Test the UPDATE triggers
-- Valid raise (+20% for Alice)
UPDATE employees SET salary = salary * 1.20 WHERE email = 'alice.johnson@company.com';

-- Try an invalid large decrease (should fail)
-- Uncomment to test the error:
-- UPDATE employees SET salary = 10000 WHERE email = 'alice.johnson@company.com';

-- View the salary audit trail
SELECT
    sl.log_id                               AS 'Log #',
    CONCAT(e.first_name,' ',e.last_name)    AS 'Employee',
    CONCAT('$', FORMAT(sl.old_salary, 2))   AS 'Old Salary',
    CONCAT('$', FORMAT(sl.new_salary, 2))   AS 'New Salary',
    CONCAT(sl.change_pct, '%')              AS 'Change %',
    sl.action_type                          AS 'Action',
    sl.change_time                          AS 'When'
FROM salary_audit_log sl
INNER JOIN employees e ON sl.emp_id = e.emp_id
ORDER BY sl.log_id DESC;

-- ─────────────────────────────────────────
-- STEP 5 : AFTER DELETE trigger – log terminations
-- ─────────────────────────────────────────

DELIMITER $$

CREATE TRIGGER trg_after_employee_delete
AFTER DELETE ON employees
FOR EACH ROW
BEGIN
    INSERT INTO employee_activity_log (action, emp_id, details)
    VALUES (
        'TERMINATED',
        OLD.emp_id,
        CONCAT('Removed: ', OLD.first_name, ' ', OLD.last_name,
               ' | Last salary: $', FORMAT(OLD.salary, 2))
    );
END $$

DELIMITER ;

-- Test delete trigger (soft-delete bypass – use hard delete to trigger it)
DELETE FROM employees WHERE email = 'sophie.clark@company.com';
SELECT * FROM employee_activity_log ORDER BY logged_at DESC LIMIT 5;

-- ─────────────────────────────────────────
-- PART B : TRANSACTIONS
-- ─────────────────────────────────────────
-- A TRANSACTION groups multiple SQL statements into ONE atomic unit.
-- Either ALL succeed (COMMIT) or ALL are undone (ROLLBACK).
-- This ensures data consistency (ACID properties).

-- ─────────────────────────────────────────
-- STEP 6 : Basic TRANSACTION with COMMIT
-- ─────────────────────────────────────────

-- Disable auto-commit so we control when changes are permanent
START TRANSACTION;

    -- Transfer budget: move $5000 from Marketing to Operations
    -- This is a two-step operation; both must succeed together
    UPDATE departments SET location = 'Building D' WHERE dept_name = 'Marketing';
    UPDATE departments SET location = 'Building D' WHERE dept_name = 'Operations';

    -- Everything looks good – make changes permanent
COMMIT;

-- Verify
SELECT dept_name, location FROM departments;

-- ─────────────────────────────────────────
-- STEP 7 : TRANSACTION with ROLLBACK
-- ─────────────────────────────────────────

-- Simulate a failed multi-step operation
START TRANSACTION;

    -- Step 1: Add a new employee
    INSERT INTO employees (first_name, last_name, email, hire_date, salary, dept_id)
    VALUES ('Temp', 'Employee', 'temp@company.com', CURDATE(), 50000, 1);

    -- Check how many employees we have now
    SELECT COUNT(*) AS 'Count during transaction' FROM employees;

    -- Step 2: Something goes wrong (e.g., invalid dept_id = 999)
    -- Instead of committing bad data, we roll back
    ROLLBACK;   -- Undo ALL changes made since START TRANSACTION

-- Verify the insert was rolled back
SELECT COUNT(*) AS 'Count after rollback' FROM employees;

-- ─────────────────────────────────────────
-- STEP 8 : SAVEPOINT – partial rollback
-- ─────────────────────────────────────────

START TRANSACTION;

    INSERT INTO departments (dept_name, location) VALUES ('R&D', 'Building E');
    -- Mark a savepoint here
    SAVEPOINT sp_after_dept;

    INSERT INTO departments (dept_name, location) VALUES ('Legal', 'Building F');
    -- Oh no – we want Legal but not R&D? Roll back only to the savepoint
    ROLLBACK TO SAVEPOINT sp_after_dept;
    -- (R&D insert is rolled back; we're now just before Legal)

    INSERT INTO departments (dept_name, location) VALUES ('Legal', 'Building F');

COMMIT;

-- Verify: R&D should NOT be there; Legal SHOULD be
SELECT dept_name, location FROM departments ORDER BY dept_id;

-- ─────────────────────────────────────────
-- STEP 9 : Show all triggers
-- ─────────────────────────────────────────

SELECT
    trigger_name    AS 'Trigger',
    event_manipulation AS 'Event',
    event_object_table AS 'Table',
    action_timing   AS 'Timing'
FROM   information_schema.triggers
WHERE  trigger_schema = 'CompanyDB'
ORDER  BY event_object_table, action_timing;

-- ============================================================
--  END OF PROJECT 8
--  Key concepts learned:
--   ✔ CREATE TRIGGER (BEFORE / AFTER × INSERT / UPDATE / DELETE)
--   ✔ NEW and OLD pseudo-row references
--   ✔ SIGNAL SQLSTATE for custom error raising
--   ✔ Audit log pattern (salary_audit_log, activity_log)
--   ✔ START TRANSACTION / COMMIT / ROLLBACK
--   ✔ SAVEPOINT and ROLLBACK TO SAVEPOINT
--   ✔ ACID properties overview through practice
-- ============================================================
