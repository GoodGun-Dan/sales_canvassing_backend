-- Migrasi aman untuk database yang SUDAH berisi data.
-- Jangan jalankan database_schema_fixed.sql pada database lama karena file itu
-- menghapus seluruh tabel. Jalankan script ini sekali di Supabase SQL Editor.

-- Konsistensi aturan duplikasi dengan validasi API.
CREATE UNIQUE INDEX IF NOT EXISTS uq_employee_email_ci
    ON employee (LOWER(email));
CREATE UNIQUE INDEX IF NOT EXISTS uq_user_account_username_ci
    ON user_account (LOWER(username));
CREATE UNIQUE INDEX IF NOT EXISTS uq_employee_phone_normalized
    ON employee ((regexp_replace(phone, '[[:space:]-]', '', 'g')))
    WHERE phone IS NOT NULL AND btrim(phone) <> '';

-- Kolom dan tabel ini dibuat defensif agar migrasi juga dapat dipakai oleh
-- database versi lama yang belum memiliki GPS, assignment, atau notifikasi.
ALTER TABLE employee ADD COLUMN IF NOT EXISTS last_lat DECIMAL(10,8);
ALTER TABLE employee ADD COLUMN IF NOT EXISTS last_lng DECIMAL(11,8);
ALTER TABLE employee ADD COLUMN IF NOT EXISTS last_location_update TIMESTAMP;

CREATE TABLE IF NOT EXISTS notification (
    notification_id SERIAL PRIMARY KEY,
    employee_id INTEGER NOT NULL REFERENCES employee(employee_id) ON DELETE CASCADE,
    type VARCHAR(50) NOT NULL,
    title VARCHAR(200) NOT NULL,
    message TEXT NOT NULL,
    related_id INTEGER,
    is_read BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS idx_notification_employee ON notification(employee_id);
CREATE INDEX IF NOT EXISTS idx_notification_read ON notification(is_read);
CREATE INDEX IF NOT EXISTS idx_notification_created ON notification(created_at DESC);

-- Perbaiki hash akun demo pada database yang sebelumnya diimpor dari schema lama.
-- Wajib ganti password ini sebelum produksi.
UPDATE user_account SET password_hash = '$2b$10$XLUYQEWZYcq/JvdUdIzp0.rUViy1OnThZamL2v.exnbQb3ok7Kcj.' WHERE username = 'admin';
UPDATE user_account SET password_hash = '$2b$10$La.jMKNJjW6r1wNgR3MNauo7qG3tHZk.sDMVjuWgGXaHXNn2Tu/Y6' WHERE username = 'manager';
UPDATE user_account SET password_hash = '$2b$10$F.S5m9jYsD8ktvDuSGIIiOvhCN6nNNryZZbfdMf5SFps1tVDt3HR2' WHERE username = 'repa';
UPDATE user_account SET password_hash = '$2b$10$7Xwa5TBGcjexNZpfYZ.KG.fJw.NUzpWA8wBxm93U8v.2bg.ySbzw6' WHERE username = 'repb';
UPDATE user_account SET password_hash = '$2b$10$ApHrRXO.fwF8ofBXvgUsB.N9Q.L2zfc5UnaVNzDv1dP5LclAA9Xcy' WHERE username = 'supervisor';
