# pearl_pay

A new Flutter project.

UPDATE deductions d
JOIN employee_salaries e ON d.employee_id = e.employee_id
SET d.company_id = e.company_id;

ALTER TABLE deductions
ADD COLUMN company_id INT NOT NULL;
