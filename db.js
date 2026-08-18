const { Pool } = require('pg');
require('dotenv').config();

// Konfigurasi koneksi dari file .env
const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
});

// Cek koneksi saat pertama kali
pool.connect((err, client, release) => {
  if (err) {
    console.error('?? Gagal konek ke PostgreSQL:', err.message);
    console.error('   Periksa DATABASE_URL di file .env');
    console.error('   Periksa file .env (DB_HOST, DB_USER, DB_PASSWORD, DB_NAME)');
  } else {
    console.log('? Berhasil terkoneksi ke PostgreSQL (Supabase)');
    release();
  }
});

module.exports = pool;
