-- Jalankan di pgAdmin jika trigger stock gagal saat import (versi PostgreSQL lama).
DROP TRIGGER IF EXISTS trigger_stock_change ON stock;
DROP FUNCTION IF EXISTS log_stock_change();

CREATE OR REPLACE FUNCTION log_stock_change()
RETURNS TRIGGER AS $$
BEGIN
    IF (OLD.quantity != NEW.quantity) THEN
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
