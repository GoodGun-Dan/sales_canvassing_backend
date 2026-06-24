/**
 * Jalankan sekali setelah import SQL agar password login valid:
 * node scripts/set-dev-passwords.js
 *
 * Default: admin/admin, manager/manager, repa/repa, repb/repb
 */
require('dotenv').config({ path: require('path').join(__dirname, '..', '.env') });
const bcrypt = require('bcrypt');
const pool = require('../db');

const USERS = {
  admin: 'admin',
  manager: 'manager',
  repa: 'repa',
  repb: 'repb',
  supervisor: 'supervisor',
};

async function main() {
  for (const [username, password] of Object.entries(USERS)) {
    const hash = await bcrypt.hash(password, 10);
    const result = await pool.query(
      'UPDATE user_account SET password_hash = $1 WHERE username = $2 RETURNING username',
      [hash, username]
    );
    if (result.rowCount === 0) {
      console.warn(`⚠️ User tidak ditemukan: ${username}`);
    } else {
      console.log(`✅ Password diupdate: ${username} / ${password}`);
    }
  }
  await pool.end();
  console.log('Selesai.');
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
