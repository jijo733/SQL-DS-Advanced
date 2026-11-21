-- ============================================================
--  PROJECT 7 (INTERMEDIATE) : Stored Procedures & Functions
--  Topic Coverage : CREATE PROCEDURE, IN/OUT/INOUT parameters,
--  IF/ELSEIF/ELSE, LOOP/WHILE/REPEAT, CURSOR, CREATE FUNCTION,
--  CALL, DROP PROCEDURE, error handling with DECLARE … HANDLER
--  Tool : MySQL Workbench
--  NOTE : Run Projects 1–6 first.
-- ============================================================

USE CompanyDB;

-- ─────────────────────────────────────────
-- MySQL requires changing the delimiter when creating
-- multi-statement routines, so the semicolons inside
-- the body don't confuse the client.
-- ─────────────────────────────────────────

-- ─────────────────────────────────────────
-- STEP 1 : Simple stored procedure – no parameters
-- ─────────────────────────────────────────

DELIMITER $$

-- Procedure: show a full employee report
CREATE PROCEDURE sp_employee_report()
BEGIN
    -- A stored procedure is a named block of SQL you can CALL later
    SELECT
        e.emp_id                                    AS 'ID',
        CONCAT(e.first_name, ' ', e.last_name)      AS 'Full Name',
        d.dept_name                                 AS 'Department',
        jt.title_name                               AS 'Job Title',
        CONCAT('$', FORMAT(e.salary, 2))            AS 'Salary',
        e.hire_date                                 AS 'Hire Date'
    FROM       employees   e
    INNER JOIN departments d  ON e.dept_id  = d.dept_id
    LEFT  JOIN job_titles  jt ON e.title_id = jt.title_id
    WHERE e.is_active = 1
    ORDER BY d.dept_name, e.last_name;
END $$

DELIMITER ;

-- Call the procedure
CALL sp_employee_report();

-- ─────────────────────────────────────────
-- STEP 2 : Procedure with IN parameter
-- ─────────────────────────────────────────

DELIMITER $$

-- Procedure: get employees in a specific department
CREATE PROCEDURE sp_employees_by_dept(
    IN p_dept_id INT   -- IN: caller passes a value; procedure reads it only
)
BEGIN
    SELECT
        CONCAT(first_name, ' ', last_name)  AS 'Full Name',
        salary                              AS 'Salary',
        hire_date                           AS 'Hire Date'
    FROM  employees
    WHERE dept_id = p_dept_id
    ORDER BY salary DESC;
END $$

DELIMITER ;

-- Call with different departments
CALL sp_employees_by_dept(1);   -- Engineering
CALL sp_employees_by_dept(2);   -- Human Resources

-- ─────────────────────────────────────────
-- STEP 3 : Procedure with OUT parameter
-- ─────────────────────────────────────────

DELIMITER $$

-- Procedure: calculate department payroll and return total via OUT param
CREATE PROCEDURE sp_dept_payroll(
    IN  p_dept_id     INT,
    OUT p_total       DECIMAL(12,2),  -- OUT: procedure sets this; caller reads it
    OUT p_head_count  INT
)
BEGIN
    SELECT  SUM(salary),  COUNT(*)
    INTO    p_total,      p_head_count
    FROM    employees
    WHERE   dept_id  = p_dept_id
      AND   is_active = 1;
END $$

DELIMITER ;

-- Call the procedure, store results in session variables (@total, @count)
CALL sp_dept_payroll(1, @total, @count);

-- Read the OUT variables
SELECT
    @total  AS 'Engineering Total Payroll',
    @count  AS 'Engineering Head Count';

-- ─────────────────────────────────────────
-- STEP 4 : Procedure with IF / ELSEIF / ELSE logic
-- ─────────────────────────────────────────

DELIMITER $$

-- Procedure: give a salary raise based on performance rating
-- Rating 1=Excellent (+15%), 2=Good (+10%), 3=Average (+5%), else no raise
CREATE PROCEDURE sp_apply_raise(
    IN p_emp_id    INT,
    IN p_rating    TINYINT
)
BEGIN
    DECLARE v_raise_pct DECIMAL(5,2) DEFAULT 0;
    DECLARE v_name      VARCHAR(101);

    -- Look up employee name
    SELECT CONCAT(first_name, ' ', last_name)
    INTO   v_name
    FROM   employees
    WHERE  emp_id = p_emp_id;

    -- Determine raise percentage based on rating
    IF p_rating = 1 THEN
        SET v_raise_pct = 0.15;              -- 15% for Excellent
    ELSEIF p_rating = 2 THEN
        SET v_raise_pct = 0.10;              -- 10% for Good
    ELSEIF p_rating = 3 THEN
        SET v_raise_pct = 0.05;              -- 5%  for Average
    ELSE
        SET v_raise_pct = 0;                 -- No raise for other ratings
    END IF;

    -- Apply the raise
    UPDATE employees
    SET    salary = salary * (1 + v_raise_pct)
    WHERE  emp_id = p_emp_id;

    -- Report what happened
    SELECT
        v_name                                     AS 'Employee',
        p_rating                                   AS 'Rating',
        CONCAT(v_raise_pct * 100, '%')             AS 'Raise Applied';
END $$

DELIMITER ;

-- Apply raises to a few employees
CALL sp_apply_raise(2, 1);   -- Bob Smith: Excellent → +15%
CALL sp_apply_raise(3, 2);   -- Carol White: Good    → +10%
CALL sp_apply_raise(4, 4);   -- David Brown: No raise

-- ─────────────────────────────────────────
-- STEP 5 : Stored FUNCTION – returns a single computed value
-- ─────────────────────────────────────────

DELIMITER $$

-- Function: calculate years of service for an employee
-- Functions must RETURN a value and use RETURNS keyword
CREATE FUNCTION fn_years_of_service(p_hire_date DATE)
RETURNS INT
DETERMINISTIC   -- same input always gives same output (required for replication)
BEGIN
    RETURN FLOOR(DATEDIFF(CURDATE(), p_hire_date) / 365);
END $$

DELIMITER ;

-- Use the function in a SELECT query – call it like any built-in function
SELECT
    CONCAT(first_name, ' ', last_name)          AS 'Full Name',
    hire_date                                   AS 'Hire Date',
    fn_years_of_service(hire_date)              AS 'Years of Service',
    CONCAT('$', FORMAT(salary, 2))              AS 'Current Salary'
FROM employees
ORDER BY fn_years_of_service(hire_date) DESC;

-- ─────────────────────────────────────────
-- STEP 6 : Stored FUNCTION – salary grade label
-- ─────────────────────────────────────────

DELIMITER $$

CREATE FUNCTION fn_salary_grade(p_salary DECIMAL(10,2))
RETURNS VARCHAR(20)
DETERMINISTIC
BEGIN
    DECLARE v_grade VARCHAR(20);

    IF    p_salary >= 90000  THEN SET v_grade = 'Executive';
    ELSEIF p_salary >= 70000 THEN SET v_grade = 'Senior';
    ELSEIF p_salary >= 50000 THEN SET v_grade = 'Mid-Level';
    ELSE                          SET v_grade = 'Junior';
    END IF;

    RETURN v_grade;
END $$

DELIMITER ;

-- Use the salary grade function
SELECT
    CONCAT(first_name, ' ', last_name)  AS 'Full Name',
    CONCAT('$', FORMAT(salary, 2))      AS 'Salary',
    fn_salary_grade(salary)             AS 'Salary Grade'
FROM employees
ORDER BY salary DESC;

-- ─────────────────────────────────────────
-- STEP 7 : Procedure with a CURSOR (iterate rows)
-- ─────────────────────────────────────────

DELIMITER $$

-- Procedure: loop over all employees and print a summary message
-- Cursors let you process result-set rows one at a time
CREATE PROCEDURE sp_print_employee_summary()
BEGIN
    -- Declare variables to hold each row's data
    DECLARE v_done      INT DEFAULT FALSE;
    DECLARE v_name      VARCHAR(101);
    DECLARE v_dept      VARCHAR(100);
    DECLARE v_salary    DECIMAL(10,2);

    -- Declare the cursor (the SELECT it will iterate)
    DECLARE cur_emp CURSOR FOR
        SELECT CONCAT(e.first_name, ' ', e.last_name), d.dept_name, e.salary
        FROM   employees e
        INNER  JOIN departments d ON e.dept_id = d.dept_id
        WHERE  e.is_active = 1
        ORDER  BY e.last_name;

    -- Handler: when cursor has no more rows, set v_done = TRUE
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET v_done = TRUE;

    -- Temporary table to hold output (so we can SELECT it all at once)
    DROP TEMPORARY TABLE IF EXISTS tmp_summary;
    CREATE TEMPORARY TABLE tmp_summary (
        employee_name VARCHAR(101),
        department    VARCHAR(100),
        salary_info   VARCHAR(100)
    );

    OPEN cur_emp;                            -- Open the cursor

    read_loop: LOOP
        FETCH cur_emp INTO v_name, v_dept, v_salary;  -- Get next row
        IF v_done THEN
            LEAVE read_loop;                 -- Exit loop when no more rows
        END IF;

        -- Insert a formatted row into the temp table
        INSERT INTO tmp_summary VALUES (
            v_name,
            v_dept,
            CONCAT('$', FORMAT(v_salary, 2))
        );
    END LOOP;

    CLOSE cur_emp;                           -- Always close the cursor

    -- Return the results
    SELECT
        employee_name   AS 'Employee',
        department      AS 'Department',
        salary_info     AS 'Salary'
    FROM tmp_summary
    ORDER BY department, employee_name;

    DROP TEMPORARY TABLE tmp_summary;
END $$

DELIMITER ;

-- Run the cursor-based procedure
CALL sp_print_employee_summary();

-- ─────────────────────────────────────────
-- STEP 8 : List and drop procedures / functions
-- ─────────────────────────────────────────

-- List all stored procedures in CompanyDB
SELECT routine_name AS 'Procedure Name', routine_type AS 'Type'
FROM   information_schema.routines
WHERE  routine_schema = 'CompanyDB'
ORDER  BY routine_type, routine_name;

-- Drop a specific procedure (safe re-run)
DROP PROCEDURE IF EXISTS sp_print_employee_summary;
DROP FUNCTION  IF EXISTS fn_salary_grade;

-- ============================================================
--  END OF PROJECT 7
--  Key concepts learned:
--   ✔ DELIMITER change for multi-statement blocks
--   ✔ CREATE PROCEDURE with no parameters
--   ✔ IN parameters (read-only from caller)
--   ✔ OUT parameters (written by procedure, read by caller)
--   ✔ DECLARE local variables
--   ✔ IF / ELSEIF / ELSE logic
--   ✔ CREATE FUNCTION with RETURNS
--   ✔ CURSOR + LOOP + FETCH + NOT FOUND HANDLER
--   ✔ CALL statement
--   ✔ DROP PROCEDURE / DROP FUNCTION
-- ============================================================
