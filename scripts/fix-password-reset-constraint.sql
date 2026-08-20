-- Add unique constraint to password_reset table for employee_id
-- This is needed for the ON CONFLICT clause in forgot password endpoint

-- First, remove any duplicate employee_id entries (keep the most recent one)
DELETE FROM password_reset
WHERE reset_id NOT IN (
    SELECT MAX(reset_id)
    FROM password_reset
    GROUP BY employee_id
);

-- Add unique constraint on employee_id
ALTER TABLE password_reset
ADD CONSTRAINT password_reset_employee_id_key UNIQUE (employee_id);
