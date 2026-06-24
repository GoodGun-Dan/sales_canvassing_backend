-- Opsional: tambah user supervisor (jalankan di pgAdmin setelah script utama)
-- Password di-set via: node scripts/set-dev-passwords.js (tambahkan supervisor di script)

INSERT INTO employee (nik, name, email, phone, section_id, position)
VALUES ('SUP001', 'Supervisor Jakarta', 'supervisor@company.com', '08123456786', 1, 'Sales Supervisor')
ON CONFLICT DO NOTHING;

-- Sesuaikan employee_id jika perlu, lalu:
-- INSERT INTO user_account (employee_id, username, password_hash, role, manager_id, is_verified)
-- VALUES (<employee_id>, 'supervisor', '<bcrypt_hash>', 'supervisor', 2, TRUE);
