const pool = require('../db');

async function main() {
  console.log('Running GPS tracking migration...');
  await pool.query(`
    ALTER TABLE employee 
    ADD COLUMN IF NOT EXISTS last_lat DECIMAL(10,8),
    ADD COLUMN IF NOT EXISTS last_lng DECIMAL(11,8),
    ADD COLUMN IF NOT EXISTS last_location_update TIMESTAMP;
  `);
  console.log('✅ Columns last_lat, last_lng, last_location_update added successfully.');
  await pool.end();
}

main().catch(err => {
  console.error('Migration failed:', err);
  process.exit(1);
});
