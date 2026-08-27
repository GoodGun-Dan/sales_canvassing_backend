-- RBAC revision: keep a single administrator account and speed up team scopes.
-- Review existing accounts before running this migration: it refuses to continue
-- if more than one admin account already exists.
DO $$
BEGIN
  IF (SELECT COUNT(*) FROM user_account WHERE role = 'admin') > 1 THEN
    RAISE EXCEPTION 'More than one admin exists. Keep the intended account, then change the others to manager or deactivate them.';
  END IF;
END $$;

CREATE UNIQUE INDEX IF NOT EXISTS uq_single_admin_account
  ON user_account ((role))
  WHERE role = 'admin';

CREATE INDEX IF NOT EXISTS idx_team_member_employee
  ON team_member (employee_id);

