-- =====================================================
-- MIGRASI V2: hubungkan modul + isolasi data per sales rep
-- Jalankan di pgAdmin (database: sales_canvassing) SETELAH script utama
-- =====================================================

-- 1. Assignment outlet permanen per sales rep
CREATE TABLE IF NOT EXISTS outlet_assignment (
    assignment_id SERIAL PRIMARY KEY,
    outlet_id INTEGER NOT NULL REFERENCES outlet(outlet_id) ON DELETE CASCADE,
    employee_id INTEGER NOT NULL REFERENCES employee(employee_id) ON DELETE CASCADE,
    assigned_by INTEGER REFERENCES employee(employee_id),
    assigned_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    is_active BOOLEAN DEFAULT TRUE,
    UNIQUE(outlet_id, employee_id)
);

CREATE INDEX IF NOT EXISTS idx_outlet_assignment_employee ON outlet_assignment(employee_id);
CREATE INDEX IF NOT EXISTS idx_outlet_assignment_outlet ON outlet_assignment(outlet_id);

-- 2. Outstanding piutang per rep per outlet (bukan global)
CREATE TABLE IF NOT EXISTS outlet_rep_balance (
    balance_id SERIAL PRIMARY KEY,
    outlet_id INTEGER NOT NULL REFERENCES outlet(outlet_id) ON DELETE CASCADE,
    employee_id INTEGER NOT NULL REFERENCES employee(employee_id) ON DELETE CASCADE,
    outstanding DECIMAL(10,2) DEFAULT 0,
    last_update TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(outlet_id, employee_id)
);

CREATE INDEX IF NOT EXISTS idx_outlet_rep_balance_employee ON outlet_rep_balance(employee_id);

-- 3. Isi assignment dari visit yang sudah ada
INSERT INTO outlet_assignment (outlet_id, employee_id, assigned_by, is_active)
SELECT DISTINCT v.outlet_id, v.employee_id, 1, TRUE
FROM visit v
WHERE NOT EXISTS (
    SELECT 1 FROM outlet_assignment oa
    WHERE oa.outlet_id = v.outlet_id AND oa.employee_id = v.employee_id
);

-- 4. Inisialisasi saldo piutang per rep dari order yang sudah ada
INSERT INTO outlet_rep_balance (outlet_id, employee_id, outstanding)
SELECT v.outlet_id, v.employee_id,
       COALESCE(SUM(so.total), 0) - COALESCE(SUM(paid.paid_amount), 0)
FROM visit v
JOIN sales_order so ON so.visit_id = v.visit_id
LEFT JOIN (
    SELECT order_id, SUM(amount) AS paid_amount FROM payment GROUP BY order_id
) paid ON paid.order_id = so.order_id
GROUP BY v.outlet_id, v.employee_id
HAVING COALESCE(SUM(so.total), 0) - COALESCE(SUM(paid.paid_amount), 0) > 0
ON CONFLICT (outlet_id, employee_id) DO UPDATE
SET outstanding = EXCLUDED.outstanding, last_update = CURRENT_TIMESTAMP;

-- 5. Perbaiki trigger stock (kompatibel PostgreSQL lama & baru)
DROP TRIGGER IF EXISTS trigger_stock_change ON stock;
DROP FUNCTION IF EXISTS log_stock_change();

CREATE OR REPLACE FUNCTION log_stock_change()
RETURNS TRIGGER AS $$
BEGIN
    IF (OLD.quantity IS DISTINCT FROM NEW.quantity) THEN
        INSERT INTO stock_history (product_id, employee_id, type, old_quantity, new_quantity, change_amount, changed_by)
        VALUES (NEW.product_id, NEW.employee_id, NEW.type, OLD.quantity, NEW.quantity, NEW.quantity - OLD.quantity, NEW.updated_by);
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_stock_change
AFTER UPDATE ON stock
FOR EACH ROW
EXECUTE PROCEDURE log_stock_change();

-- 6. User supervisor (opsional)
INSERT INTO employee (nik, name, email, phone, section_id, position)
SELECT 'SUP001', 'Supervisor Jakarta', 'supervisor@company.com', '08123456786', 1, 'Sales Supervisor'
WHERE NOT EXISTS (SELECT 1 FROM employee WHERE nik = 'SUP001');

INSERT INTO user_account (employee_id, username, password_hash, role, manager_id, is_verified)
SELECT e.employee_id, 'supervisor',
       '$2b$10$placeholderwillbesetbysetuppasswords000000000000000000000',
       'supervisor', 2, TRUE
FROM employee e WHERE e.nik = 'SUP001'
AND NOT EXISTS (SELECT 1 FROM user_account WHERE username = 'supervisor');

INSERT INTO team_member (team_id, employee_id)
SELECT 1, e.employee_id FROM employee e WHERE e.nik = 'SUP001'
AND NOT EXISTS (
    SELECT 1 FROM team_member tm WHERE tm.team_id = 1 AND tm.employee_id = e.employee_id
);

SELECT '✅ Migrasi V2 selesai. Jalankan: npm run setup-passwords' AS status;
