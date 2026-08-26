-- Hapus semua tabel jika ada (start fresh)
DROP TABLE IF EXISTS stock_history CASCADE;
DROP TABLE IF EXISTS notification CASCADE;
DROP TABLE IF EXISTS promotion CASCADE;
DROP TABLE IF EXISTS merchandising_audit CASCADE;
DROP TABLE IF EXISTS payment CASCADE;
DROP TABLE IF EXISTS order_detail CASCADE;
DROP TABLE IF EXISTS sales_order CASCADE;
DROP TABLE IF EXISTS visit CASCADE;
DROP TABLE IF EXISTS password_reset CASCADE;
DROP TABLE IF EXISTS outlet_assignment CASCADE;
DROP TABLE IF EXISTS outlet_rep_balance CASCADE;
DROP TABLE IF EXISTS outlet CASCADE;
DROP TABLE IF EXISTS product CASCADE;
DROP TABLE IF EXISTS unit CASCADE;
DROP TABLE IF EXISTS user_account CASCADE;
DROP TABLE IF EXISTS employee CASCADE;
DROP TABLE IF EXISTS section CASCADE;
DROP TABLE IF EXISTS stock CASCADE;
DROP TABLE IF EXISTS team_member CASCADE;
DROP TABLE IF EXISTS team CASCADE;

-- =====================================================
-- 1. TABEL MASTER
-- =====================================================

-- Section (departemen/tim)
CREATE TABLE section (
    section_id SERIAL PRIMARY KEY,
    section_code VARCHAR(20) NOT NULL UNIQUE,
    section_name VARCHAR(100) NOT NULL,
    description TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Employee (semua karyawan) - DITAMBAHKAN KOLOM GPS
CREATE TABLE employee (
    employee_id SERIAL PRIMARY KEY,
    nik VARCHAR(20) NOT NULL UNIQUE,
    name VARCHAR(100) NOT NULL,
    email VARCHAR(100) NOT NULL UNIQUE,
    phone VARCHAR(20),
    section_id INTEGER REFERENCES section(section_id),
    position VARCHAR(50),
    created_by INTEGER REFERENCES employee(employee_id),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    is_active BOOLEAN DEFAULT TRUE,
    last_lat DECIMAL(10,8),
    last_lng DECIMAL(11,8),
    last_location_update TIMESTAMP
);

-- User Account (login credentials)
CREATE TABLE user_account (
    user_id SERIAL PRIMARY KEY,
    employee_id INTEGER UNIQUE NOT NULL REFERENCES employee(employee_id) ON DELETE CASCADE,
    username VARCHAR(50) NOT NULL UNIQUE,
    password_hash VARCHAR(255) NOT NULL,
    role VARCHAR(20) NOT NULL CHECK (role IN ('admin', 'manager', 'supervisor', 'rep')),
    company_email VARCHAR(100),
    is_verified BOOLEAN DEFAULT FALSE,
    manager_id INTEGER REFERENCES employee(employee_id),
    last_login TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Proteksi duplikasi juga harus ada di database, bukan hanya di aplikasi.
-- Email dan username tidak membedakan huruf besar/kecil; nomor telepon
-- dibandingkan setelah spasi dan tanda hubung dihapus.
CREATE UNIQUE INDEX uq_employee_email_ci ON employee (LOWER(email));
CREATE UNIQUE INDEX uq_user_account_username_ci ON user_account (LOWER(username));
CREATE UNIQUE INDEX uq_employee_phone_normalized
    ON employee ((regexp_replace(phone, '[[:space:]-]', '', 'g')))
    WHERE phone IS NOT NULL AND btrim(phone) <> '';

-- Team
CREATE TABLE team (
    team_id SERIAL PRIMARY KEY,
    team_name VARCHAR(100) NOT NULL,
    manager_id INTEGER NOT NULL REFERENCES employee(employee_id),
    company_domain VARCHAR(100) NOT NULL,
    description TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Team Member
CREATE TABLE team_member (
    team_member_id SERIAL PRIMARY KEY,
    team_id INTEGER NOT NULL REFERENCES team(team_id) ON DELETE CASCADE,
    employee_id INTEGER NOT NULL REFERENCES employee(employee_id) ON DELETE CASCADE,
    joined_date DATE DEFAULT CURRENT_DATE,
    UNIQUE(team_id, employee_id)
);

-- Unit
CREATE TABLE unit (
    unit_id SERIAL PRIMARY KEY,
    unit_name VARCHAR(20) NOT NULL UNIQUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Product
CREATE TABLE product (
    product_id SERIAL PRIMARY KEY,
    product_code VARCHAR(50) NOT NULL UNIQUE,
    product_name VARCHAR(100) NOT NULL,
    product_type VARCHAR(20) NOT NULL CHECK (product_type IN ('Sparepart', 'Finished Goods')),
    unit_id INTEGER REFERENCES unit(unit_id),
    min_stock INTEGER DEFAULT 0,
    price DECIMAL(10,2) NOT NULL,
    created_by INTEGER REFERENCES employee(employee_id),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    is_active BOOLEAN DEFAULT TRUE
);

-- Outlet
CREATE TABLE outlet (
    outlet_id SERIAL PRIMARY KEY,
    outlet_code VARCHAR(20) NOT NULL UNIQUE,
    outlet_name VARCHAR(100) NOT NULL,
    address TEXT NOT NULL,
    latitude DECIMAL(10,8),
    longitude DECIMAL(11,8),
    owner_name VARCHAR(100),
    phone VARCHAR(20),
    credit_limit DECIMAL(10,2) DEFAULT 0,
    outstanding DECIMAL(10,2) DEFAULT 0,
    priority CHAR(1) CHECK (priority IN ('A', 'B', 'C')),
    store_type VARCHAR(50),
    created_by INTEGER REFERENCES employee(employee_id),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    is_active BOOLEAN DEFAULT TRUE
);

-- =====================================================
-- PERUBAHAN PENTING: Tabel STOCK dengan employee_id
-- =====================================================
CREATE TABLE stock (
    stock_id SERIAL PRIMARY KEY,
    product_id INTEGER NOT NULL REFERENCES product(product_id),
    employee_id INTEGER NOT NULL REFERENCES employee(employee_id),
    type VARCHAR(20) NOT NULL CHECK (type IN ('distributor', 'van', 'outlet')),
    quantity INTEGER NOT NULL DEFAULT 0,
    last_update TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_by INTEGER REFERENCES employee(employee_id),
    UNIQUE(product_id, type, employee_id)
);

-- Stock History (perbaiki sesuai struktur baru)
CREATE TABLE stock_history (
    history_id SERIAL PRIMARY KEY,
    product_id INTEGER NOT NULL REFERENCES product(product_id),
    employee_id INTEGER NOT NULL REFERENCES employee(employee_id),
    type VARCHAR(20) NOT NULL,
    old_quantity INTEGER NOT NULL,
    new_quantity INTEGER NOT NULL,
    change_amount INTEGER NOT NULL,
    reason VARCHAR(100),
    changed_by INTEGER REFERENCES employee(employee_id),
    changed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- =====================================================
-- 2. TABEL TRANSAKSI
-- =====================================================

-- Visit
CREATE TABLE visit (
    visit_id SERIAL PRIMARY KEY,
    employee_id INTEGER NOT NULL REFERENCES employee(employee_id),
    outlet_id INTEGER NOT NULL REFERENCES outlet(outlet_id),
    visit_date DATE NOT NULL DEFAULT CURRENT_DATE,
    visit_time TIME,
    check_in_time TIMESTAMP,
    check_out_time TIMESTAMP,
    check_in_lat DECIMAL(10,8),
    check_in_lng DECIMAL(11,8),
    visit_reason VARCHAR(100),
    status VARCHAR(20) DEFAULT 'Planned' CHECK (status IN ('Planned', 'InProgress', 'Completed', 'Missed', 'Cancelled', 'Permission', 'Expired')),
    notes TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Password Reset
CREATE TABLE password_reset (
    reset_id SERIAL PRIMARY KEY,
    employee_id INTEGER NOT NULL REFERENCES employee(employee_id),
    email VARCHAR(255) NOT NULL,
    verification_code VARCHAR(6) NOT NULL,
    expires_at TIMESTAMP NOT NULL,
    used BOOLEAN DEFAULT false,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(employee_id)
);

-- Outlet Assignment (assign outlets to sales reps)
CREATE TABLE outlet_assignment (
    assignment_id SERIAL PRIMARY KEY,
    outlet_id INTEGER NOT NULL REFERENCES outlet(outlet_id) ON DELETE CASCADE,
    employee_id INTEGER NOT NULL REFERENCES employee(employee_id) ON DELETE CASCADE,
    assigned_by INTEGER REFERENCES employee(employee_id),
    assigned_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    is_active BOOLEAN DEFAULT TRUE,
    UNIQUE(outlet_id, employee_id)
);

-- Outlet Rep Balance (outstanding balance per rep per outlet)
CREATE TABLE outlet_rep_balance (
    balance_id SERIAL PRIMARY KEY,
    outlet_id INTEGER NOT NULL REFERENCES outlet(outlet_id) ON DELETE CASCADE,
    employee_id INTEGER NOT NULL REFERENCES employee(employee_id) ON DELETE CASCADE,
    outstanding DECIMAL(10,2) DEFAULT 0,
    last_update TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(outlet_id, employee_id)
);

-- Sales Order
CREATE TABLE sales_order (
    order_id SERIAL PRIMARY KEY,
    order_number VARCHAR(20) NOT NULL UNIQUE,
    visit_id INTEGER NOT NULL REFERENCES visit(visit_id),
    order_type VARCHAR(20) NOT NULL CHECK (order_type IN ('Sales', 'Pre-order', 'Return', 'FOC')),
    order_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    subtotal DECIMAL(10,2) NOT NULL,
    discount DECIMAL(10,2) DEFAULT 0,
    tax DECIMAL(10,2) DEFAULT 0,
    total DECIMAL(10,2) NOT NULL,
    signature BYTEA,
    sync_status VARCHAR(10) DEFAULT 'Pending' CHECK (sync_status IN ('Pending', 'Synced')),
    approved_by INTEGER REFERENCES employee(employee_id),
    approved_at TIMESTAMP,
    notes TEXT
);

-- Order Detail
CREATE TABLE order_detail (
    detail_id SERIAL PRIMARY KEY,
    order_id INTEGER NOT NULL REFERENCES sales_order(order_id) ON DELETE CASCADE,
    product_id INTEGER NOT NULL REFERENCES product(product_id),
    quantity INTEGER NOT NULL,
    unit_price DECIMAL(10,2) NOT NULL,
    subtotal DECIMAL(10,2) GENERATED ALWAYS AS (quantity * unit_price) STORED
);

-- Payment
CREATE TABLE payment (
    payment_id SERIAL PRIMARY KEY,
    order_id INTEGER NOT NULL REFERENCES sales_order(order_id),
    payment_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    amount DECIMAL(10,2) NOT NULL,
    payment_method VARCHAR(20) NOT NULL CHECK (payment_method IN ('Cash', 'Transfer', 'UPI', 'Wallet')),
    receipt_image BYTEA,
    reference_number VARCHAR(50),
    sync_status VARCHAR(10) DEFAULT 'Pending' CHECK (sync_status IN ('Pending', 'Synced')),
    recorded_by INTEGER REFERENCES employee(employee_id)
);

-- Merchandising Audit
CREATE TABLE merchandising_audit (
    audit_id SERIAL PRIMARY KEY,
    visit_id INTEGER NOT NULL UNIQUE REFERENCES visit(visit_id),
    planogram_score INTEGER CHECK (planogram_score BETWEEN 0 AND 100),
    shelf_share INTEGER,
    posm_placement BOOLEAN DEFAULT FALSE,
    photo BYTEA,
    notes TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Promotion
CREATE TABLE promotion (
    promotion_id SERIAL PRIMARY KEY,
    promotion_code VARCHAR(20) NOT NULL UNIQUE,
    description TEXT,
    type VARCHAR(20) NOT NULL CHECK (type IN ('Quantity-based', 'Value-based', 'Time-bound', 'Outlet-specific')),
    conditions JSONB,
    reward JSONB,
    start_date DATE NOT NULL,
    end_date DATE NOT NULL,
    is_active BOOLEAN DEFAULT TRUE,
    created_by INTEGER REFERENCES employee(employee_id),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- =====================================================
-- 3. INDEXES
-- =====================================================

CREATE INDEX idx_visit_employee_date ON visit(employee_id, visit_date);
CREATE INDEX idx_visit_employee_status_date ON visit(employee_id, status, visit_date);
CREATE INDEX idx_visit_outlet ON visit(outlet_id);
CREATE INDEX idx_sales_order_visit ON sales_order(visit_id);
CREATE INDEX idx_sales_order_date ON sales_order(order_date);
CREATE INDEX idx_sales_order_visit_date ON sales_order(visit_id, order_date);
CREATE INDEX idx_order_detail_order ON order_detail(order_id);
CREATE INDEX idx_order_detail_product ON order_detail(product_id);
CREATE INDEX idx_payment_order ON payment(order_id);
CREATE INDEX idx_stock_product ON stock(product_id);
CREATE INDEX idx_stock_employee ON stock(employee_id);
CREATE INDEX idx_user_account_role ON user_account(role);
CREATE INDEX idx_employee_section ON employee(section_id);
CREATE INDEX idx_team_manager ON team(manager_id);
CREATE INDEX idx_team_member_team ON team_member(team_id);
CREATE INDEX idx_team_member_employee ON team_member(employee_id);
CREATE INDEX idx_employee_location ON employee(last_location_update, last_lat, last_lng);
CREATE INDEX idx_password_reset_email_code ON password_reset(email, verification_code);
CREATE INDEX idx_password_reset_employee ON password_reset(employee_id);
CREATE INDEX idx_outlet_assignment_employee ON outlet_assignment(employee_id);
CREATE INDEX idx_outlet_assignment_employee_active ON outlet_assignment(employee_id, is_active);
CREATE INDEX idx_outlet_assignment_outlet ON outlet_assignment(outlet_id);
CREATE INDEX idx_outlet_rep_balance_employee ON outlet_rep_balance(employee_id);
CREATE INDEX idx_outlet_rep_balance_outlet ON outlet_rep_balance(outlet_id);

-- =====================================================
-- 4. SAMPLE DATA
-- =====================================================

-- Section
INSERT INTO section (section_code, section_name, description) VALUES
('SLS-JKT', 'Sales Jakarta', 'Jakarta sales team'),
('SLS-BDG', 'Sales Bandung', 'Bandung sales team');

-- Employee (Sales Reps, Managers, Admin)
INSERT INTO employee (nik, name, email, phone, section_id, position) VALUES
('ADM001', 'Admin', 'admin@company.com', '08123456788', 1, 'System Administrator'),
('MGR001', 'Manager Jakarta', 'manager.jkt@company.com', '08123456787', 1, 'Sales Manager'),
('SR001', 'Sales Rep A', 'rep.a@company.com', '08123456789', 1, 'Sales Representative'),
('SR002', 'Sales Rep B', 'rep.b@company.com', '08123456780', 1, 'Sales Representative');

-- User Account - DIPERBAIKI: Valid bcrypt hashes
INSERT INTO user_account (employee_id, username, password_hash, role, company_email, is_verified) VALUES
(1, 'admin', '$2b$10$XLUYQEWZYcq/JvdUdIzp0.rUViy1OnThZamL2v.exnbQb3ok7Kcj.', 'admin', 'admin@company.com', TRUE),
(2, 'manager', '$2b$10$La.jMKNJjW6r1wNgR3MNauo7qG3tHZk.sDMVjuWgGXaHXNn2Tu/Y6', 'manager', 'manager.jkt@company.com', TRUE),
(3, 'repa', '$2b$10$F.S5m9jYsD8ktvDuSGIIiOvhCN6nNNryZZbfdMf5SFps1tVDt3HR2', 'rep', 'rep.a@company.com', TRUE),
(4, 'repb', '$2b$10$7Xwa5TBGcjexNZpfYZ.KG.fJw.NUzpWA8wBxm93U8v.2bg.ySbzw6', 'rep', 'rep.b@company.com', TRUE);

-- Team
INSERT INTO team (team_name, manager_id, company_domain, description) VALUES
('Jakarta Sales Team', 2, '@company.com', 'All sales reps for Jakarta area');

-- Team Member
INSERT INTO team_member (team_id, employee_id) VALUES
(1, 3),
(1, 4);

-- Unit
INSERT INTO unit (unit_name) VALUES ('Pcs'), ('Box'), ('Pack');

-- Product
INSERT INTO product (product_code, product_name, product_type, unit_id, min_stock, price, created_by) VALUES
('EM-250-RED', 'EnergiMax Drink 250ml', 'Finished Goods', 1, 50, 15000, 1),
('HP-VITC-100', 'HealthPlus Vitamin C', 'Finished Goods', 1, 30, 45000, 1),
('AP-600-BLUE', 'AquaPure Water 600ml', 'Finished Goods', 1, 20, 8500, 1),
('ST-CHIPS-150', 'SnackTime Chips 150g', 'Finished Goods', 1, 40, 12500, 1);

-- Outlet
INSERT INTO outlet (outlet_code, outlet_name, address, latitude, longitude, owner_name, phone, credit_limit, outstanding, priority, store_type, created_by) VALUES
('OUT-001', 'Toko Maju Jaya', 'Jl. Merdeka No. 123', -6.2088, 106.8456, 'Budi Santoso', '021-5556789', 5000000, 2450000, 'A', 'Supermarket', 1),
('OUT-002', 'Toko Sejahtera', 'Jl. Sudirman No. 45', -6.2095, 106.8460, 'Sari Wijaya', '021-5559876', 3000000, 1850000, 'B', 'Mini Market', 1),
('OUT-003', 'Toko Makmur Abadi', 'Jl. Thamrin No. 67', -6.2078, 106.8448, 'Agus Setiawan', '021-5551234', 4000000, 950000, 'B', 'Retail', 1),
('OUT-004', 'Toko Baru Jaya', 'Jl. Gatot Subroto No. 89', -6.2102, 106.8475, 'Dewi Anggraeni', '021-5554321', 2000000, 1200000, 'C', 'Warung', 1);

-- =====================================================
-- SAMPLE STOCK DATA (per sales rep - satu sales satu data)
-- =====================================================

-- Stock untuk Sales Rep A (employee_id = 3)
INSERT INTO stock (product_id, employee_id, type, quantity, updated_by) VALUES
(1, 3, 'distributor', 420, 1),
(1, 3, 'van', 25, 1),
(1, 3, 'outlet', 15, 1),
(2, 3, 'distributor', 85, 1),
(2, 3, 'van', 12, 1),
(2, 3, 'outlet', 8, 1),
(3, 3, 'distributor', 32, 1),
(3, 3, 'van', 5, 1),
(3, 3, 'outlet', 3, 1),
(4, 3, 'distributor', 120, 1),
(4, 3, 'van', 18, 1),
(4, 3, 'outlet', 12, 1);

-- Stock untuk Sales Rep B (employee_id = 4)
INSERT INTO stock (product_id, employee_id, type, quantity, updated_by) VALUES
(1, 4, 'distributor', 300, 1),
(1, 4, 'van', 15, 1),
(1, 4, 'outlet', 10, 1),
(2, 4, 'distributor', 60, 1),
(2, 4, 'van', 8, 1),
(2, 4, 'outlet', 5, 1),
(3, 4, 'distributor', 20, 1),
(3, 4, 'van', 3, 1),
(3, 4, 'outlet', 2, 1),
(4, 4, 'distributor', 90, 1),
(4, 4, 'van', 12, 1),
(4, 4, 'outlet', 8, 1);

-- Visit Plan for today (Sales Rep A)
INSERT INTO visit (employee_id, outlet_id, visit_date, visit_time, status) VALUES
(3, 1, CURRENT_DATE, '09:30', 'Planned'),
(3, 2, CURRENT_DATE, '10:45', 'Planned'),
(3, 3, CURRENT_DATE, '12:00', 'Planned'),
(3, 4, CURRENT_DATE, '14:15', 'Planned');

-- Visit Plan for today (Sales Rep B)
INSERT INTO visit (employee_id, outlet_id, visit_date, visit_time, status) VALUES
(4, 1, CURRENT_DATE, '09:00', 'Planned'),
(4, 2, CURRENT_DATE, '10:30', 'Planned'),
(4, 3, CURRENT_DATE, '11:45', 'Planned');

-- Sample Order
INSERT INTO sales_order (order_number, visit_id, order_type, subtotal, discount, tax, total, sync_status) VALUES
('SO-2026-0401-001', 1, 'Sales', 300000, 0, 30000, 330000, 'Synced');

INSERT INTO order_detail (order_id, product_id, quantity, unit_price) VALUES
(1, 1, 20, 15000);

-- Sample Payment
INSERT INTO payment (order_id, amount, payment_method, sync_status) VALUES
(1, 330000, 'Cash', 'Synced');

-- Outlet Assignment (assign outlets to sales reps)
INSERT INTO outlet_assignment (outlet_id, employee_id, assigned_by, is_active) VALUES
(1, 3, 1, TRUE),
(2, 3, 1, TRUE),
(3, 3, 1, TRUE),
(4, 3, 1, TRUE),
(1, 4, 1, TRUE),
(2, 4, 1, TRUE),
(3, 4, 1, TRUE);

-- Outlet Rep Balance (outstanding balance per rep per outlet)
INSERT INTO outlet_rep_balance (outlet_id, employee_id, outstanding) VALUES
(1, 3, 2450000),
(2, 3, 1850000),
(3, 3, 950000),
(4, 3, 1200000),
(1, 4, 1500000),
(2, 4, 900000),
(3, 4, 500000);

-- Supervisor User
INSERT INTO employee (nik, name, email, phone, section_id, position) VALUES
('SUP001', 'Supervisor Jakarta', 'supervisor@company.com', '08123456786', 1, 'Sales Supervisor');

INSERT INTO user_account (employee_id, username, password_hash, role, manager_id, is_verified) VALUES
(5, 'supervisor', '$2b$10$ApHrRXO.fwF8ofBXvgUsB.N9Q.L2zfc5UnaVNzDv1dP5LclAA9Xcy', 'supervisor', 2, TRUE);

INSERT INTO team_member (team_id, employee_id) VALUES
(1, 5);

-- =====================================================
-- Notification System
-- =====================================================

CREATE TABLE notification (
    notification_id SERIAL PRIMARY KEY,
    employee_id INTEGER NOT NULL REFERENCES employee(employee_id) ON DELETE CASCADE,
    type VARCHAR(50) NOT NULL,
    title VARCHAR(200) NOT NULL,
    message TEXT NOT NULL,
    related_id INTEGER,
    is_read BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_notification_employee ON notification(employee_id);
CREATE INDEX idx_notification_read ON notification(is_read);
CREATE INDEX idx_notification_created ON notification(created_at DESC);

-- =====================================================
-- 5. TRIGGERS & FUNCTIONS (diperbaiki untuk employee_id)
-- =====================================================

-- Function to update stock history (kompatibel PostgreSQL lama & baru)
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

-- Trigger untuk mencatat perubahan stock
CREATE TRIGGER trigger_stock_change
AFTER UPDATE ON stock
FOR EACH ROW
EXECUTE PROCEDURE log_stock_change();

-- =====================================================
-- 6. VIEWS FOR REPORTS
-- =====================================================

-- View untuk dashboard sales rep
CREATE OR REPLACE VIEW v_sales_dashboard AS
SELECT 
    e.employee_id,
    e.name,
    COUNT(DISTINCT v.visit_id) as total_visits,
    COUNT(DISTINCT CASE WHEN v.status = 'Completed' THEN v.visit_id END) as completed_visits,
    COUNT(DISTINCT so.order_id) as total_orders,
    COALESCE(SUM(so.total), 0) as total_sales,
    COALESCE(SUM(p.amount), 0) as total_collection
FROM employee e
LEFT JOIN visit v ON v.employee_id = e.employee_id AND v.visit_date = CURRENT_DATE
LEFT JOIN sales_order so ON so.visit_id = v.visit_id
LEFT JOIN payment p ON p.order_id = so.order_id
GROUP BY e.employee_id, e.name;

-- View untuk manajer (ringkasan tim)
CREATE OR REPLACE VIEW v_team_performance AS
SELECT 
    t.team_id,
    t.team_name,
    e.employee_id,
    e.name as sales_name,
    COUNT(DISTINCT v.visit_id) as total_visits,
    COUNT(DISTINCT so.order_id) as total_orders,
    COALESCE(SUM(so.total), 0) as total_sales
FROM team t
JOIN team_member tm ON tm.team_id = t.team_id
JOIN employee e ON e.employee_id = tm.employee_id
LEFT JOIN visit v ON v.employee_id = e.employee_id AND v.visit_date = CURRENT_DATE
LEFT JOIN sales_order so ON so.visit_id = v.visit_id
GROUP BY t.team_id, t.team_name, e.employee_id, e.name;

-- =====================================================
-- SELESAI
-- =====================================================
SELECT '✅ Database Mobile Sales Canvassing selesai dibuat!' as status;
