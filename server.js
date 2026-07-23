require('dotenv').config();

const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const rateLimit = require('express-rate-limit');
const bcrypt = require('bcrypt');
const jwt = require('jsonwebtoken');
const multer = require('multer');
const XLSX = require('xlsx');

// Coba load database, jika gagal tetap lanjut
let pool;
try {
  pool = require('./db');
  console.log('✅ Database module loaded');
} catch (err) {
  console.error('⚠️ Database module not found:', err.message);
  pool = null;
}

const app = express();
const PORT = 3000;

// JWT_SECRET harus di-set di environment variable, jangan gunakan default value untuk production
const JWT_SECRET = process.env.JWT_SECRET;
if (!JWT_SECRET) {
  console.error('❌ ERROR: JWT_SECRET environment variable tidak di-set!');
  console.error('Silakan buat file .env dan set JWT_SECRET dengan nilai yang kuat.');
  console.error('Contoh: JWT_SECRET=your-very-long-random-secret-key-minimum-32-characters');
  process.exit(1);
}

// =====================================================
// LOGGING GLOBAL - UNTUK MELIHAT SEMUA REQUEST
// =====================================================
app.use((req, res, next) => {
  console.log(`📥 ${req.method} ${req.url}`);
  next();
});

// Middleware
// Security headers dengan Helmet
app.use(helmet());

// Rate limiting untuk mencegah brute force dan DDoS
const limiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 menit
  max: 100, // maksimal 100 request per 15 menit per IP
  message: 'Terlalu banyak request dari IP ini, coba lagi nanti.',
  standardHeaders: true,
  legacyHeaders: false,
});

// Rate limiting yang lebih ketat untuk endpoint login
const loginLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 menit
  max: 5, // maksimal 5 percobaan login per 15 menit per IP
  message: 'Terlalu banyak percobaan login gagal. Akun terkunci sementara, coba lagi dalam 15 menit.',
  standardHeaders: true,
  legacyHeaders: false,
});

app.use(limiter);

// CORS configuration - restrict ke origin tertentu untuk security
const corsOptions = {
  origin: function (origin, callback) {
    // Allow request dengan no origin (mobile apps, curl, Postman)
    if (!origin) return callback(null, true);
    
    // List allowed origins (sesuaikan dengan production domain)
    const allowedOrigins = [
      'http://localhost:3000',
      'http://localhost:8080',
      'http://127.0.0.1:3000',
      'http://127.0.0.1:8080',
      'https://salescanvassingbackend-production.up.railway.app',
      'capacitor://localhost',
      'http://localhost'
    ];
    
    if (allowedOrigins.indexOf(origin) !== -1) {
      callback(null, true);
    } else {
      callback(new Error('Not allowed by CORS'));
    }
  },
  credentials: true, // jika menggunakan cookies/auth headers
  optionsSuccessStatus: 200 // some legacy browsers choke on 204
};

app.use(cors(corsOptions));
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// Konfigurasi multer untuk upload file Excel
const storage = multer.memoryStorage();
const upload = multer({ 
  storage: storage,
  limits: { fileSize: 5 * 1024 * 1024 },
  fileFilter: (req, file, cb) => {
    // Check file extension instead of mimetype for more reliable detection
    const allowedExtensions = ['.xlsx', '.xls'];
    const fileExtension = file.originalname.toLowerCase().substring(file.originalname.lastIndexOf('.'));
    
    if (allowedExtensions.includes(fileExtension)) {
      cb(null, true);
    } else {
      cb(new Error('Hanya file Excel (.xlsx, .xls) yang diperbolehkan'));
    }
  }
});

// Error handler untuk multer - return JSON instead of HTML
app.use((err, req, res, next) => {
  console.error('Error in request:', err);
  
  if (err instanceof multer.MulterError) {
    if (err.code === 'LIMIT_FILE_SIZE') {
      return res.status(400).json({ error: 'File terlalu besar. Maksimal 5MB' });
    }
    if (err.code === 'LIMIT_UNEXPECTED_FILE') {
      return res.status(400).json({ error: 'Field file tidak ditemukan' });
    }
    return res.status(400).json({ error: err.message });
  }
  if (err.message && err.message.includes('Hanya file Excel')) {
    return res.status(400).json({ error: err.message });
  }
  
  // Return JSON for all errors
  return res.status(500).json({ error: err.message || 'Internal server error' });
});

// =====================================================
// MIDDLEWARE AUTHENTICATION & AUTHORIZATION
// =====================================================

function authenticate(req, res, next) {
  const authHeader = req.headers.authorization;
  if (!authHeader) {
    return res.status(401).json({ error: 'No token provided' });
  }

  const token = authHeader.split(' ')[1];
  try {
    const decoded = jwt.verify(token, JWT_SECRET);
    req.user = decoded;
    next();
  } catch (err) {
    return res.status(401).json({ error: 'Invalid token' });
  }
}

function authorize(...roles) {
  return (req, res, next) => {
    if (!roles.includes(req.user.role)) {
      return res.status(403).json({ error: 'Forbidden: Insufficient permissions' });
    }
    next();
  };
}

/** Sales rep hanya boleh akses data sendiri; admin/manager/supervisor boleh rep_id query */
function resolveRepId(req) {
  if (req.user.role === 'rep') {
    return req.user.employee_id;
  }
  if (req.query.rep_id) {
    return parseInt(req.query.rep_id, 10);
  }
  if (req.params.id) {
    return parseInt(req.params.id, 10);
  }
  return req.user.employee_id;
}

async function getTeamEmployeeIds(managerId) {
  if (!pool) return null;
  const result = await pool.query(
    `SELECT tm.employee_id
     FROM team_member tm
     JOIN team t ON t.team_id = tm.team_id
     WHERE t.manager_id = $1`,
    [managerId]
  );
  return result.rows.map((r) => r.employee_id);
}

async function ensureOutletAssignment(client, outletId, employeeId, assignedBy) {
  await client.query(
    `INSERT INTO outlet_assignment (outlet_id, employee_id, assigned_by, is_active)
     VALUES ($1, $2, $3, TRUE)
     ON CONFLICT (outlet_id, employee_id)
     DO UPDATE SET is_active = TRUE, assigned_at = CURRENT_TIMESTAMP`,
    [outletId, employeeId, assignedBy]
  );
}

async function tablesReady() {
  if (!pool) return { assignment: false, balance: false };
  try {
    const r = await pool.query(
      `SELECT
         EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'outlet_assignment') AS assignment,
         EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'outlet_rep_balance') AS balance`
    );
    return r.rows[0];
  } catch {
    return { assignment: false, balance: false };
  }
}

function calculateDistance(lat1, lon1, lat2, lon2) {
  const R = 6371e3;
  const φ1 = lat1 * Math.PI / 180;
  const φ2 = lat2 * Math.PI / 180;
  const Δφ = (lat2 - lat1) * Math.PI / 180;
  const Δλ = (lon2 - lon1) * Math.PI / 180;
  const a = Math.sin(Δφ/2) * Math.sin(Δφ/2) +
            Math.cos(φ1) * Math.cos(φ2) *
            Math.sin(Δλ/2) * Math.sin(Δλ/2);
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1-a));
  return R * c;
}

// =====================================================
// ROOT — jangan buka hanya http://localhost:3000/ tanpa /api
// =====================================================
app.get('/', (req, res) => {
  res.json({
    status: 'ok',
    message: 'Mobile Sales Canvassing API — server berjalan.',
    database: pool ? 'connected' : 'not connected',
    cek_kesehatan: `http://localhost:${PORT}/api/test`,
    login: `POST http://localhost:${PORT}/api/auth/login`,
    body_login: { username: 'repa', password: 'repa' },
    catatan: 'Semua endpoint API ada di path /api/... (bukan di / saja).',
  });
});

app.get('/api', (req, res) => {
  res.json({
    status: 'ok',
    endpoints_utama: [
      'GET  /api/test',
      'POST /api/auth/login',
      'GET  /api/dashboard (Bearer token)',
    ],
  });
});

// =====================================================
// TEST ENDPOINT
// =====================================================
app.get('/api/test', (req, res) => {
  res.json({ 
    status: 'success', 
    message: 'Server is running!',
    time: new Date().toISOString(),
    database: pool ? 'connected' : 'not connected'
  });
});

// =====================================================
// AUTHENTICATION ENDPOINTS
// =====================================================

app.post('/api/auth/login', loginLimiter, async (req, res) => {
  const { username, password } = req.body;

  if (!username || !password) {
    return res.status(400).json({ error: 'Username and password required' });
  }

  if (!pool) {
    const mockUsers = {
      'admin': { employee_id: 1, name: 'Administrator', role: 'admin', password: 'admin' },
      'manager': { employee_id: 2, name: 'Manager', role: 'manager', password: 'manager' },
      'repa': { employee_id: 3, name: 'Sales Rep A', role: 'rep', password: 'repa' },
      'repb': { employee_id: 4, name: 'Sales Rep B', role: 'rep', password: 'repb' },
      'supervisor': { employee_id: 2, name: 'Supervisor', role: 'supervisor', password: 'supervisor' }
    };
    
    const user = mockUsers[username];
    if (user && user.password === password) {
      const token = jwt.sign(
        { user_id: user.employee_id, employee_id: user.employee_id, username, role: user.role },
        JWT_SECRET,
        { expiresIn: '24h' }
      );
      return res.json({
        success: true,
        token,
        user: {
          id: user.employee_id,
          username,
          role: user.role,
          name: user.name,
        },
      });
    }
    return res.status(401).json({ error: 'Invalid credentials' });
  }

  try {
    const result = await pool.query(
      `SELECT u.user_id, u.employee_id, u.username, u.role, u.password_hash, e.name, e.is_active
       FROM user_account u 
       JOIN employee e ON e.employee_id = u.employee_id 
       WHERE u.username = $1`,
      [username]
    );

    if (result.rows.length === 0) {
      return res.status(401).json({ error: 'Invalid credentials' });
    }

    const user = result.rows[0];

    if (user.is_active === false) {
      return res.status(401).json({ error: 'Account is deactivated' });
    }

    const passwordValid = await bcrypt.compare(password, user.password_hash);
    if (!passwordValid) {
      return res.status(401).json({
        error:
          'Username atau password salah. Setelah import SQL, jalankan: npm run setup-passwords',
      });
    }

    const token = jwt.sign(
      { user_id: user.user_id, employee_id: user.employee_id, username: user.username, role: user.role },
      JWT_SECRET,
      { expiresIn: '24h' }
    );

    await pool.query(`UPDATE user_account SET last_login = NOW() WHERE user_id = $1`, [user.user_id]);

    res.json({
      success: true,
      token,
      user: {
        id: user.employee_id,
        username: user.username,
        role: user.role,
        name: user.name
      }
    });
  } catch (err) {
    console.error('Login error:', err);
    res.status(500).json({ error: 'Login failed' });
  }
});

app.get('/api/auth/profile', authenticate, async (req, res) => {
  if (!pool) {
    return res.json({ employee_id: req.user.employee_id, name: 'User', role: req.user.role });
  }

  try {
    const result = await pool.query(
      `SELECT e.employee_id, e.name, e.email, e.phone, u.username, u.role
       FROM employee e
       JOIN user_account u ON u.employee_id = e.employee_id
       WHERE e.employee_id = $1`,
      [req.user.employee_id]
    );
    res.json(result.rows[0] || { employee_id: req.user.employee_id, role: req.user.role });
  } catch (err) {
    res.status(500).json({ error: 'Failed to get profile' });
  }
});

app.put('/api/auth/profile', authenticate, async (req, res) => {
  const { name, email, phone } = req.body;
  const employeeId = req.user.employee_id;

  if (!pool) {
    return res.json({ success: true, name, email, phone });
  }

  if (!name || !email) {
    return res.status(400).json({ error: 'Name and email required' });
  }

  try {
    await pool.query(
      `UPDATE employee SET name = $1, email = $2, phone = $3 WHERE employee_id = $4`,
      [name, email, phone, employeeId]
    );
    res.json({ success: true, name, email, phone });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.post('/api/auth/change-password', authenticate, async (req, res) => {
  const { oldPassword, newPassword } = req.body;
  const employeeId = req.user.employee_id;

  if (!oldPassword || !newPassword) {
    return res.status(400).json({ error: 'Old and new password required' });
  }

  // Password complexity validation
  if (newPassword.length < 8) {
    return res.status(400).json({ error: 'Password minimal 8 karakter' });
  }
  
  const hasUpperCase = /[A-Z]/.test(newPassword);
  const hasLowerCase = /[a-z]/.test(newPassword);
  const hasNumber = /[0-9]/.test(newPassword);
  const hasSpecialChar = /[!@#$%^&*(),.?":{}|<>]/.test(newPassword);
  
  if (!hasUpperCase || !hasLowerCase || !hasNumber || !hasSpecialChar) {
    return res.status(400).json({ 
      error: 'Password harus mengandung minimal 1 huruf besar, 1 huruf kecil, 1 angka, dan 1 karakter khusus (!@#$%^&*(),.?":{}|<>)' 
    });
  }

  if (!pool) {
    return res.json({ success: true });
  }

  try {
    const result = await pool.query(
      `SELECT password_hash FROM user_account WHERE employee_id = $1`,
      [employeeId]
    );
    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'User not found' });
    }

    const valid = await bcrypt.compare(oldPassword, result.rows[0].password_hash);
    if (!valid) {
      return res.status(401).json({ error: 'Password lama salah' });
    }

    const hash = await bcrypt.hash(newPassword, 10);
    await pool.query(
      `UPDATE user_account SET password_hash = $1 WHERE employee_id = $2`,
      [hash, employeeId]
    );
    res.json({ success: true, message: 'Password updated' });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// =====================================================
// ADMIN ENDPOINTS - MANAGE SALES REPS
// =====================================================

// Get all sales reps (for admin/manager dashboard)
app.get('/api/admin/sales-reps', authenticate, authorize('admin', 'manager'), async (req, res) => {
  if (!pool) {
    return res.json([
      { employee_id: 3, name: 'Sales Rep A', email: 'rep.a@company.com', username: 'repa', role: 'rep', phone: '08123456789', joined_date: '2026-01-01', total_visits: 12, total_sales: 5000000, is_active: true },
      { employee_id: 4, name: 'Sales Rep B', email: 'rep.b@company.com', username: 'repb', role: 'rep', phone: '08123456780', joined_date: '2026-01-15', total_visits: 8, total_sales: 3200000, is_active: true }
    ]);
  }

  try {
    let query = `
      SELECT 
        e.employee_id,
        e.name,
        e.email,
        e.phone,
        e.created_at as joined_date,
        u.username,
        u.role,
        u.is_verified,
        e.is_active,
        COUNT(DISTINCT v.visit_id) as total_visits,
        COALESCE(SUM(so.total), 0) as total_sales
      FROM employee e
      JOIN user_account u ON u.employee_id = e.employee_id
      LEFT JOIN visit v ON v.employee_id = e.employee_id
      LEFT JOIN sales_order so ON so.visit_id = v.visit_id
      WHERE u.role = 'rep'`;
    const params = [];

    if (req.user.role === 'manager') {
      const teamIds = await getTeamEmployeeIds(req.user.employee_id);
      if (teamIds && teamIds.length > 0) {
        params.push(teamIds);
        query += ` AND e.employee_id = ANY($1::int[])`;
      }
    }

    query += `
      GROUP BY e.employee_id, e.name, e.email, e.phone, e.created_at, u.username, u.role, u.is_verified, e.is_active
      ORDER BY e.name`;

    const result = await pool.query(query, params);
    res.json(result.rows);
  } catch (err) {
    console.error('Error fetching sales reps:', err);
    res.status(500).json({ error: err.message });
  }
});

// Get single sales rep details
app.get('/api/admin/sales-reps/:id', authenticate, authorize('admin', 'manager'), async (req, res) => {
  const repId = req.params.id;
  
  if (!pool) {
    return res.json({ employee_id: repId, name: 'Sales Rep', email: 'rep@company.com', username: 'rep', phone: '08123456789', joined_date: '2026-01-01', is_active: true });
  }

  try {
    const result = await pool.query(`
      SELECT 
        e.employee_id,
        e.name,
        e.email,
        e.phone,
        e.created_at as joined_date,
        u.username,
        u.role,
        u.is_verified,
        e.is_active
      FROM employee e
      JOIN user_account u ON u.employee_id = e.employee_id
      WHERE e.employee_id = $1 AND u.role = 'rep'
    `, [repId]);
    
    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Sales rep not found' });
    }
    res.json(result.rows[0]);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Get complete dashboard data for a specific sales rep (for admin/manager viewing)
app.get('/api/admin/sales-reps/:id/dashboard', authenticate, authorize('admin', 'manager'), async (req, res) => {
  const repId = req.params.id;
  
  if (!pool) {
    return res.json({
      repInfo: { employee_id: repId, name: 'Sales Rep', email: 'rep@company.com', username: 'rep' },
      visitPlan: [
        { outlet_id: 1, outlet_name: "Toko Maju Jaya", address: "Jl. Merdeka No. 123", priority: "A", visit_time: "09:30:00", status: "Planned", latitude: -6.2088, longitude: 106.8456 }
      ],
      metrics: { totalSalesToday: 330000, strikeRate: 50.0, pendingOrders: 0 },
      lastSync: new Date().toISOString()
    });
  }

  try {
    const repInfo = await pool.query(`
      SELECT e.employee_id, e.name, e.email, e.phone, u.username
      FROM employee e
      JOIN user_account u ON u.employee_id = e.employee_id
      WHERE e.employee_id = $1
    `, [repId]);

    const visitPlanResult = await pool.query(`
      SELECT o.outlet_id, o.outlet_name, o.address, o.priority, v.visit_time, v.status, o.latitude, o.longitude
      FROM outlet o 
      JOIN visit v ON v.outlet_id = o.outlet_id
      WHERE v.employee_id = $1 AND v.visit_date = CURRENT_DATE
      AND v.status IN ('Planned', 'InProgress')
      ORDER BY v.visit_time
    `, [repId]);

    const metricsResult = await pool.query(`
      SELECT 
        COALESCE(SUM(so.total), 0) as total_sales_today,
        COUNT(DISTINCT v.visit_id) as total_visits,
        COUNT(DISTINCT CASE WHEN so.order_id IS NOT NULL THEN v.visit_id END) as productive_visits
      FROM visit v 
      LEFT JOIN sales_order so ON so.visit_id = v.visit_id
      WHERE v.employee_id = $1 AND v.visit_date = CURRENT_DATE
      AND v.status IN ('Planned', 'InProgress', 'Completed')
    `, [repId]);

    const metrics = metricsResult.rows[0];
    const strikeRate = metrics.total_visits > 0 
      ? (metrics.productive_visits / metrics.total_visits * 100).toFixed(1) 
      : 0;

    res.json({
      repInfo: repInfo.rows[0] || {},
      visitPlan: visitPlanResult.rows,
      metrics: {
        totalSalesToday: parseFloat(metrics.total_sales_today),
        strikeRate: parseFloat(strikeRate),
        pendingOrders: 0,
      },
      lastSync: new Date().toISOString(),
    });
  } catch (err) {
    console.error('Error fetching rep dashboard:', err);
    res.status(500).json({ error: err.message });
  }
});

// Get sales rep last check-in or live location for today (for admin/manager viewing)
app.get('/api/admin/sales-reps/:id/location', authenticate, authorize('admin', 'manager'), async (req, res) => {
  const repId = parseInt(req.params.id, 10);
  
  if (!pool) {
    return res.json({ latitude: -6.2088, longitude: 106.8456, last_update: new Date().toISOString(), is_live: true });
  }

  try {
    // 1. Cek live location terupdate hari ini
    const liveResult = await pool.query(
      `SELECT last_lat as latitude, last_lng as longitude, last_location_update as last_update
       FROM employee
       WHERE employee_id = $1 
         AND last_location_update::date = CURRENT_DATE 
         AND last_lat IS NOT NULL`,
      [repId]
    );

    if (liveResult.rows.length > 0 && liveResult.rows[0].latitude !== null) {
      return res.json({
        latitude: parseFloat(liveResult.rows[0].latitude),
        longitude: parseFloat(liveResult.rows[0].longitude),
        last_update: liveResult.rows[0].last_update,
        is_live: true
      });
    }

    // 2. Fallback: lokasi check-in kunjungan hari ini
    const result = await pool.query(
      `SELECT check_in_lat as latitude, check_in_lng as longitude, check_in_time as last_update
       FROM visit
       WHERE employee_id = $1 AND visit_date = CURRENT_DATE AND check_in_lat IS NOT NULL
       ORDER BY check_in_time DESC LIMIT 1`,
      [repId]
    );

    if (result.rows.length === 0) {
      return res.json({ latitude: null, longitude: null, last_update: null, is_live: false });
    }
    
    res.json({
      latitude: parseFloat(result.rows[0].latitude),
      longitude: parseFloat(result.rows[0].longitude),
      last_update: result.rows[0].last_update,
      is_live: false
    });
  } catch (err) {
    console.error('Error fetching sales rep location:', err);
    res.status(500).json({ error: err.message });
  }
});


// Get all orders for a specific sales rep (for admin/manager viewing)
app.get('/api/admin/sales-reps/:id/orders', authenticate, authorize('admin', 'manager'), async (req, res) => {
  const repId = req.params.id;
  
  if (!pool) {
    return res.json([]);
  }

  try {
    const result = await pool.query(`
      SELECT so.order_id, so.order_number, o.outlet_name, so.total, so.order_date, so.sync_status as status
      FROM sales_order so 
      JOIN visit v ON v.visit_id = so.visit_id 
      JOIN outlet o ON o.outlet_id = v.outlet_id
      WHERE v.employee_id = $1 
      ORDER BY so.order_date DESC 
      LIMIT 50
    `, [repId]);
    res.json(result.rows);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Get all payments for a specific sales rep (for admin/manager viewing)
app.get('/api/admin/sales-reps/:id/payments', authenticate, authorize('admin', 'manager'), async (req, res) => {
  const repId = req.params.id;
  
  if (!pool) {
    return res.json([]);
  }

  try {
    const result = await pool.query(`
      SELECT p.payment_id, p.order_id, p.amount, p.payment_method, p.payment_date, p.reference_number
      FROM payment p 
      JOIN sales_order so ON so.order_id = p.order_id 
      JOIN visit v ON v.visit_id = so.visit_id
      WHERE v.employee_id = $1 
      ORDER BY p.payment_date DESC 
      LIMIT 50
    `, [repId]);
    res.json(result.rows);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Get analytics for a specific sales rep (for admin/manager viewing)
app.get('/api/admin/sales-reps/:id/analytics', authenticate, authorize('admin', 'manager'), async (req, res) => {
  const repId = req.params.id;
  const days = parseInt(req.query.days) || 7;
  
  if (!pool) {
    return res.json({
      dailySales: [],
      topProducts: [],
      topOutlets: [],
      summary: { total_sales: 0, total_orders: 0, total_visits: 0, strike_rate: 0 }
    });
  }

  try {
    const dailySales = await pool.query(`
      SELECT DATE(so.order_date) as date, COALESCE(SUM(so.total), 0) as total_sales
      FROM sales_order so 
      JOIN visit v ON v.visit_id = so.visit_id
      WHERE v.employee_id = $1 AND v.visit_date >= CURRENT_DATE - ($2 || ' days')::INTERVAL
      GROUP BY DATE(so.order_date) 
      ORDER BY date ASC
    `, [repId, days]);

    const topProducts = await pool.query(`
      SELECT p.product_name, SUM(od.quantity) as total_quantity, SUM(od.quantity * od.unit_price) as total_sales
      FROM order_detail od 
      JOIN sales_order so ON so.order_id = od.order_id 
      JOIN visit v ON v.visit_id = so.visit_id 
      JOIN product p ON p.product_id = od.product_id
      WHERE v.employee_id = $1 
      GROUP BY p.product_name 
      ORDER BY total_sales DESC 
      LIMIT 5
    `, [repId]);

    const topOutlets = await pool.query(`
      SELECT o.outlet_name, COUNT(DISTINCT v.visit_id) as total_visits, COALESCE(SUM(so.total), 0) as total_sales
      FROM visit v 
      JOIN outlet o ON o.outlet_id = v.outlet_id 
      LEFT JOIN sales_order so ON so.visit_id = v.visit_id
      WHERE v.employee_id = $1 
      GROUP BY o.outlet_name 
      ORDER BY total_sales DESC 
      LIMIT 5
    `, [repId]);

    const summary = await pool.query(`
      SELECT 
        COALESCE(SUM(so.total), 0) as total_sales,
        COUNT(DISTINCT so.order_id) as total_orders,
        COUNT(DISTINCT v.visit_id) as total_visits,
        CASE WHEN COUNT(DISTINCT v.visit_id) > 0 
          THEN (COUNT(DISTINCT CASE WHEN so.order_id IS NOT NULL THEN v.visit_id END)::float / COUNT(DISTINCT v.visit_id)) * 100 
          ELSE 0 END as strike_rate
      FROM visit v 
      LEFT JOIN sales_order so ON so.visit_id = v.visit_id
      WHERE v.employee_id = $1 AND v.visit_date >= CURRENT_DATE - INTERVAL '30 days'
    `, [repId]);

    res.json({
      dailySales: dailySales.rows,
      topProducts: topProducts.rows,
      topOutlets: topOutlets.rows,
      summary: summary.rows[0] || { total_sales: 0, total_orders: 0, total_visits: 0, strike_rate: 0 }
    });
  } catch (err) {
    console.error('Error fetching rep analytics:', err);
    res.status(500).json({ error: err.message });
  }
});

// Add new sales rep
app.post('/api/admin/sales-reps', authenticate, authorize('admin', 'manager'), async (req, res) => {
  const { name, email, phone, username, password } = req.body;
  const managerId = req.user.employee_id;

  if (!name || !email || !username || !password) {
    return res.status(400).json({ error: 'Missing required fields' });
  }

  if (!pool) {
    return res.status(201).json({ success: true, message: 'Sales rep added (mock)', employee_id: Date.now() });
  }

  const client = await pool.connect();
  try {
    await client.query('BEGIN');

    const hashedPassword = await bcrypt.hash(password, 10);

    const employeeResult = await client.query(
      `INSERT INTO employee (nik, name, email, phone, created_by, position) 
       VALUES ($1, $2, $3, $4, $5, 'Sales Representative') 
       RETURNING employee_id`,
      [`EMP-${Date.now()}`, name, email, phone, managerId]
    );
    const employeeId = employeeResult.rows[0].employee_id;

    await client.query(
      `INSERT INTO user_account (employee_id, username, password_hash, role, is_verified) 
       VALUES ($1, $2, $3, 'rep', true)`,
      [employeeId, username, hashedPassword]
    );

    const teamResult = await client.query(`SELECT team_id FROM team WHERE manager_id = $1`, [managerId]);
    if (teamResult.rows.length > 0) {
      await client.query(
        `INSERT INTO team_member (team_id, employee_id) VALUES ($1, $2)`,
        [teamResult.rows[0].team_id, employeeId]
      );
    }

    await client.query('COMMIT');
    res.status(201).json({ success: true, message: 'Sales rep added successfully', employee_id: employeeId });
  } catch (err) {
    await client.query('ROLLBACK');
    console.error('Error adding sales rep:', err);
    res.status(500).json({ error: err.message });
  } finally {
    client.release();
  }
});

// Update sales rep
app.put('/api/admin/sales-reps/:id', authenticate, authorize('admin', 'manager'), async (req, res) => {
  const repId = req.params.id;
  const { name, email, phone, username, is_active } = req.body;

  if (!pool) {
    return res.json({ success: true });
  }

  try {
    await pool.query('BEGIN');

    await pool.query(
      `UPDATE employee SET name = $1, email = $2, phone = $3, is_active = $4 WHERE employee_id = $5`,
      [name, email, phone, is_active !== undefined ? is_active : true, repId]
    );

    await pool.query(
      `UPDATE user_account SET username = $1 WHERE employee_id = $2`,
      [username, repId]
    );

    await pool.query('COMMIT');
    res.json({ success: true, message: 'Sales rep updated successfully' });
  } catch (err) {
    await pool.query('ROLLBACK');
    res.status(500).json({ error: err.message });
  }
});

// =====================================================
// ASSIGN / REMOVE OUTLET TO SALES REP
// =====================================================

// Remove outlet from sales rep (update status menjadi Missed dan deactivate outlet_assignment)
// NOTE: This route must be defined BEFORE the general delete sales rep route
app.delete('/api/admin/sales-reps/:id/remove-outlet/:outlet_id', authenticate, authorize('admin', 'manager'), async (req, res) => {
  console.log('🗑️ REMOVE OUTLET ROUTE HIT!');
  const repId = parseInt(req.params.id);
  const outletId = parseInt(req.params.outlet_id);
  console.log('repId:', repId, 'outletId:', outletId);

  if (isNaN(repId) || isNaN(outletId)) {
    return res.status(400).json({ error: 'Invalid repId or outletId' });
  }

  if (!pool) {
    return res.json({ success: true, message: 'Outlet removed (mock)' });
  }

  try {
    const checkResult = await pool.query(
      `SELECT visit_id, visit_date, status 
       FROM visit 
       WHERE employee_id = $1 
       AND outlet_id = $2 
       AND visit_date >= CURRENT_DATE
       AND status IN ('Planned', 'InProgress')`,
      [repId, outletId]
    );

    if (checkResult.rows.length === 0) {
      return res.status(404).json({ 
        error: 'No active visit plan found for this outlet'
      });
    }

    const result = await pool.query(
      `UPDATE visit 
       SET status = 'Missed' 
       WHERE employee_id = $1 
       AND outlet_id = $2 
       AND visit_date >= CURRENT_DATE
       AND status IN ('Planned', 'InProgress')
       RETURNING visit_id, visit_date`,
      [repId, outletId]
    );

    // Deactivate outlet_assignment so sales rep no longer sees this outlet
    const ready = await tablesReady();
    if (ready.assignment) {
      await pool.query(
        `UPDATE outlet_assignment SET is_active = false WHERE outlet_id = $1 AND employee_id = $2`,
        [outletId, repId]
      );
    }

    res.json({ 
      success: true, 
      message: 'Outlet removed from sales rep schedule',
      visits_updated: result.rows.length
    });
  } catch (err) {
    console.error('Error removing outlet:', err);
    res.status(500).json({ error: err.message });
  }
});

// Delete sales rep (soft delete)
app.delete('/api/admin/sales-reps/:id', authenticate, authorize('admin', 'manager'), async (req, res) => {
  const repId = req.params.id;

  if (!pool) {
    return res.json({ success: true });
  }

  try {
    await pool.query(`UPDATE employee SET is_active = false WHERE employee_id = $1`, [repId]);
    await pool.query(`UPDATE user_account SET is_verified = false WHERE employee_id = $1`, [repId]);
    res.json({ success: true, message: 'Sales rep deactivated successfully' });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// =====================================================
// ASSIGN / REMOVE OUTLET TO SALES REP
// =====================================================

// Get outlets assigned to a specific sales rep (only active ones)
app.get('/api/admin/sales-reps/:id/outlets', authenticate, authorize('admin', 'manager'), async (req, res) => {
  const repId = parseInt(req.params.id);

  if (isNaN(repId)) {
    return res.status(400).json({ error: 'Invalid repId' });
  }

  if (!pool) {
    const mockOutlets = {
      3: [
        { outlet_id: 1, outlet_name: "Toko Maju Jaya", address: "Jl. Merdeka No. 123", latitude: -6.2088, longitude: 106.8456, priority: "A", store_type: "Supermarket", outlet_code: "OUT-001" },
        { outlet_id: 2, outlet_name: "Toko Sejahtera", address: "Jl. Sudirman No. 45", latitude: -6.2095, longitude: 106.8460, priority: "B", store_type: "Mini Market", outlet_code: "OUT-002" }
      ],
      4: [
        { outlet_id: 3, outlet_name: "Toko Makmur Abadi", address: "Jl. Thamrin No. 67", latitude: -6.2078, longitude: 106.8448, priority: "B", store_type: "Retail", outlet_code: "OUT-003" },
        { outlet_id: 4, outlet_name: "Toko Baru Jaya", address: "Jl. Gatot Subroto No. 89", latitude: -6.2102, longitude: 106.8475, priority: "C", store_type: "Warung", outlet_code: "OUT-004" }
      ]
    };
    return res.json(mockOutlets[repId] || []);
  }

  try {
    const result = await pool.query(`
      SELECT DISTINCT 
        o.outlet_id, 
        o.outlet_name, 
        o.address, 
        o.latitude, 
        o.longitude, 
        o.priority, 
        o.store_type,
        o.outlet_code,
        v.visit_date,
        v.visit_time,
        v.status as visit_status
      FROM outlet o
      INNER JOIN visit v ON v.outlet_id = o.outlet_id
      WHERE o.is_active = true
      AND v.employee_id = $1
      AND v.status IN ('Planned', 'InProgress')
      ORDER BY v.visit_date ASC, v.visit_time ASC
    `, [repId]);

    res.json(result.rows);
  } catch (err) {
    console.error('Error fetching assigned outlets:', err);
    res.status(500).json({ error: err.message });
  }
});

// Get all outlets that are NOT assigned to a specific sales rep
app.get('/api/admin/sales-reps/:id/available-outlets', authenticate, authorize('admin', 'manager'), async (req, res) => {
  const repId = parseInt(req.params.id);

  if (isNaN(repId)) {
    return res.status(400).json({ error: 'Invalid repId' });
  }

  if (!pool) {
    const mockOutlets = {
      3: [
        { outlet_id: 3, outlet_name: "Toko Makmur Abadi", address: "Jl. Thamrin No. 67", latitude: -6.2078, longitude: 106.8448, priority: "B", store_type: "Retail", outlet_code: "OUT-003" },
        { outlet_id: 4, outlet_name: "Toko Baru Jaya", address: "Jl. Gatot Subroto No. 89", latitude: -6.2102, longitude: 106.8475, priority: "C", store_type: "Warung", outlet_code: "OUT-004" }
      ],
      4: [
        { outlet_id: 1, outlet_name: "Toko Maju Jaya", address: "Jl. Merdeka No. 123", latitude: -6.2088, longitude: 106.8456, priority: "A", store_type: "Supermarket", outlet_code: "OUT-001" },
        { outlet_id: 2, outlet_name: "Toko Sejahtera", address: "Jl. Sudirman No. 45", latitude: -6.2095, longitude: 106.8460, priority: "B", store_type: "Mini Market", outlet_code: "OUT-002" }
      ]
    };
    return res.json(mockOutlets[repId] || [
      { outlet_id: 1, outlet_name: "Toko Maju Jaya", address: "Jl. Merdeka No. 123", latitude: -6.2088, longitude: 106.8456, priority: "A", store_type: "Supermarket", outlet_code: "OUT-001" },
      { outlet_id: 2, outlet_name: "Toko Sejahtera", address: "Jl. Sudirman No. 45", latitude: -6.2095, longitude: 106.8460, priority: "B", store_type: "Mini Market", outlet_code: "OUT-002" },
      { outlet_id: 3, outlet_name: "Toko Makmur Abadi", address: "Jl. Thamrin No. 67", latitude: -6.2078, longitude: 106.8448, priority: "B", store_type: "Retail", outlet_code: "OUT-003" },
      { outlet_id: 4, outlet_name: "Toko Baru Jaya", address: "Jl. Gatot Subroto No. 89", latitude: -6.2102, longitude: 106.8475, priority: "C", store_type: "Warung", outlet_code: "OUT-004" }
    ]);
  }

  try {
    const result = await pool.query(`
      SELECT 
        o.outlet_id, 
        o.outlet_name, 
        o.address, 
        o.latitude, 
        o.longitude, 
        o.priority, 
        o.store_type,
        o.outlet_code
      FROM outlet o
      WHERE o.is_active = true
      AND NOT EXISTS (
        SELECT 1 FROM visit v 
        WHERE v.outlet_id = o.outlet_id 
        AND v.employee_id = $1
        AND v.status IN ('Planned', 'InProgress')
      )
      ORDER BY o.priority ASC, o.outlet_name ASC
    `, [repId]);

    res.json(result.rows);
  } catch (err) {
    console.error('Error fetching available outlets:', err);
    res.status(500).json({ error: err.message });
  }
});

// Assign outlet to sales rep (create visit plan)
app.post('/api/admin/sales-reps/:id/assign-outlet', authenticate, authorize('admin', 'manager'), async (req, res) => {
  const repId = parseInt(req.params.id);
  const { outlet_id, visit_date, visit_time } = req.body;

  console.log('========================================');
  console.log('🔥 ASSIGN OUTLET REQUEST RECEIVED 🔥');
  console.log('repId:', repId);
  console.log('outlet_id:', outlet_id);
  console.log('User:', req.user);
  console.log('========================================');

  if (isNaN(repId)) {
    console.log('❌ Invalid repId');
    return res.status(400).json({ error: 'Invalid repId' });
  }

  if (!outlet_id) {
    console.log('❌ Missing outlet_id');
    return res.status(400).json({ error: 'outlet_id is required' });
  }

  const visitDate = visit_date || new Date().toISOString().split('T')[0];
  const visitTime = visit_time || '09:00:00';

  if (!pool) {
    console.log('⚠️ Using mock mode - outlet assigned');
    return res.status(200).json({ 
      success: true, 
      message: 'Outlet assigned successfully (mock)',
      visit_id: Date.now()
    });
  }

  try {
    const existingCheck = await pool.query(
      `SELECT v.visit_id, v.status 
       FROM visit v 
       WHERE v.employee_id = $1 
       AND v.outlet_id = $2 
       AND v.visit_date >= CURRENT_DATE
       AND v.status IN ('Planned', 'InProgress')`,
      [repId, outlet_id]
    );

    if (existingCheck.rows.length > 0) {
      console.log(`⚠️ Outlet ${outlet_id} already assigned to rep ${repId}`);
      return res.status(409).json({ error: 'Outlet already assigned to this sales rep' });
    }

    const outletCheck = await pool.query(
      `SELECT outlet_id, outlet_name FROM outlet WHERE outlet_id = $1 AND is_active = true`,
      [outlet_id]
    );

    if (outletCheck.rows.length === 0) {
      console.log(`❌ Outlet ${outlet_id} not found or inactive`);
      return res.status(404).json({ error: 'Outlet not found or inactive' });
    }

    const repCheck = await pool.query(
      `SELECT employee_id, name FROM employee WHERE employee_id = $1 AND is_active = true`,
      [repId]
    );

    if (repCheck.rows.length === 0) {
      console.log(`❌ Sales rep ${repId} not found or inactive`);
      return res.status(404).json({ error: 'Sales rep not found or inactive' });
    }

    const client = await pool.connect();
    let visitId;
    try {
      await client.query('BEGIN');
      const result = await client.query(
        `INSERT INTO visit (employee_id, outlet_id, visit_date, visit_time, status) 
         VALUES ($1, $2, $3, $4, 'Planned') 
         RETURNING visit_id`,
        [repId, outlet_id, visitDate, visitTime]
      );
      visitId = result.rows[0].visit_id;
      const ready = await tablesReady();
      if (ready.assignment) {
        await ensureOutletAssignment(client, outlet_id, repId, req.user.employee_id);
      }
      await client.query('COMMIT');
    } catch (txErr) {
      await client.query('ROLLBACK');
      throw txErr;
    } finally {
      client.release();
    }

    console.log(`✅ Outlet ${outlet_id} assigned to rep ${repId}, visit_id: ${visitId}`);

    return res.status(200).json({ 
      success: true, 
      message: `Outlet "${outletCheck.rows[0].outlet_name}" assigned successfully`,
      visit_id: visitId
    });

  } catch (err) {
    console.error('❌ Error assigning outlet:', err);
    return res.status(500).json({ error: err.message });
  }
});

// =====================================================
// DASHBOARD ENDPOINT (for logged in user - Sales Rep view)
// =====================================================
app.get('/api/dashboard', authenticate, async (req, res) => {
  const employeeId = req.user.employee_id;
  const role = req.user.role;

  if (!pool) {
    return res.json({
      success: true,
      visitPlan: [
        { outlet_id: 1, outlet_name: "Toko Maju Jaya", address: "Jl. Merdeka No. 123", priority: "A", visit_time: "09:30:00", status: "Planned", latitude: -6.2088, longitude: 106.8456 }
      ],
      metrics: { totalSalesToday: 330000, strikeRate: 50.0, pendingOrders: 0 },
      lastSync: new Date().toISOString()
    });
  }

  try {
    let visitPlanQuery, metricsQuery;
    let params = [employeeId];

    if (role === 'rep') {
      visitPlanQuery = `
        SELECT o.outlet_id, o.outlet_name, o.address, o.priority, v.visit_time, v.status, o.latitude, o.longitude
        FROM outlet o 
        JOIN visit v ON v.outlet_id = o.outlet_id
        WHERE v.employee_id = $1 
        AND v.visit_date = CURRENT_DATE
        AND v.status IN ('Planned', 'InProgress')
        ORDER BY v.visit_time
      `;
      metricsQuery = `
        SELECT COALESCE(SUM(so.total), 0) as total_sales_today, 
               COUNT(DISTINCT v.visit_id) as total_visits,
               COUNT(DISTINCT CASE WHEN so.order_id IS NOT NULL THEN v.visit_id END) as productive_visits,
               (SELECT COUNT(*) FROM sales_order so2
                JOIN visit v2 ON v2.visit_id = so2.visit_id
                WHERE v2.employee_id = $1 AND so2.sync_status = 'Pending') as pending_orders
        FROM visit v 
        LEFT JOIN sales_order so ON so.visit_id = v.visit_id
        WHERE v.employee_id = $1 AND v.visit_date = CURRENT_DATE
        AND v.status IN ('Planned', 'InProgress', 'Completed')
      `;
    } else {
      params = [];
      visitPlanQuery = `
        SELECT o.outlet_id, o.outlet_name, o.address, o.priority, v.visit_time, v.status, o.latitude, o.longitude, e.name as sales_name
        FROM outlet o 
        JOIN visit v ON v.outlet_id = o.outlet_id
        JOIN employee e ON e.employee_id = v.employee_id
        WHERE v.visit_date = CURRENT_DATE 
        AND v.status IN ('Planned', 'InProgress')
        ORDER BY v.visit_time
      `;
      metricsQuery = `
        SELECT COALESCE(SUM(so.total), 0) as total_sales_today, 
               COUNT(DISTINCT v.visit_id) as total_visits,
               COUNT(DISTINCT CASE WHEN so.order_id IS NOT NULL THEN v.visit_id END) as productive_visits
        FROM visit v 
        LEFT JOIN sales_order so ON so.visit_id = v.visit_id
        WHERE v.visit_date = CURRENT_DATE
        AND v.status IN ('Planned', 'InProgress', 'Completed')
      `;
    }

    const [visitPlanResult, metricsResult] = await Promise.all([
      pool.query(visitPlanQuery, params),
      pool.query(metricsQuery, params)
    ]);

    const metrics = metricsResult.rows[0];
    const strikeRate = metrics.total_visits > 0 
      ? (metrics.productive_visits / metrics.total_visits * 100).toFixed(1) 
      : 0;

    res.json({
      success: true,
      visitPlan: visitPlanResult.rows,
      metrics: {
        totalSalesToday: parseFloat(metrics.total_sales_today),
        strikeRate: parseFloat(strikeRate),
        pendingOrders: parseInt(metrics.pending_orders || 0, 10),
      },
      lastSync: new Date().toISOString(),
    });
  } catch (err) {
    console.error('Dashboard error:', err);
    res.status(500).json({ error: err.message });
  }
});

// =====================================================
// OUTLETS ENDPOINTS
// =====================================================
app.get('/api/outlets', authenticate, async (req, res) => {
  const role = req.user.role;
  const repId = role === 'rep' ? req.user.employee_id : (req.query.rep_id ? parseInt(req.query.rep_id, 10) : null);

  if (!pool) {
    let mockOutlets = [
      { outlet_id: 1, outlet_name: "Toko Maju Jaya", address: "Jl. Merdeka No. 123", latitude: -6.2088, longitude: 106.8456, priority: "A", store_type: "Supermarket", outlet_code: "OUT-001" },
      { outlet_id: 2, outlet_name: "Toko Sejahtera", address: "Jl. Sudirman No. 45", latitude: -6.2095, longitude: 106.8460, priority: "B", store_type: "Mini Market", outlet_code: "OUT-002" },
      { outlet_id: 3, outlet_name: "Toko Makmur Abadi", address: "Jl. Thamrin No. 67", latitude: -6.2078, longitude: 106.8448, priority: "B", store_type: "Retail", outlet_code: "OUT-003" },
      { outlet_id: 4, outlet_name: "Toko Baru Jaya", address: "Jl. Gatot Subroto No. 89", latitude: -6.2102, longitude: 106.8475, priority: "C", store_type: "Warung", outlet_code: "OUT-004" }
    ];
    
    if (repId) {
      const repIdNum = parseInt(repId);
      if (repIdNum === 3) {
        mockOutlets = mockOutlets.filter(o => o.outlet_id === 1 || o.outlet_id === 2);
      } else if (repIdNum === 4) {
        mockOutlets = mockOutlets.filter(o => o.outlet_id === 3 || o.outlet_id === 4);
      }
    }
    
    return res.json(mockOutlets);
  }

  try {
    const ready = await tablesReady();
    let query;
    let params = [];

    if (repId) {
      if (ready.assignment) {
        query = `
          SELECT DISTINCT o.outlet_id, o.outlet_name, o.address, o.latitude, o.longitude,
                 o.priority, o.store_type, o.outlet_code, o.credit_limit,
                 COALESCE(orb.outstanding, 0) as rep_outstanding
          FROM outlet o
          LEFT JOIN outlet_rep_balance orb
            ON orb.outlet_id = o.outlet_id AND orb.employee_id = $1
          WHERE o.is_active = true
          AND (
            o.outlet_id IN (
              SELECT oa.outlet_id FROM outlet_assignment oa
              WHERE oa.employee_id = $1 AND oa.is_active = TRUE
            )
            OR o.outlet_id IN (
              SELECT v.outlet_id FROM visit v
              WHERE v.employee_id = $1
              AND v.visit_date = CURRENT_DATE
              AND v.status IN ('Planned', 'InProgress', 'Completed')
            )
          )
          ORDER BY o.priority ASC, o.outlet_name ASC`;
        params = [repId];
      } else {
        query = `
          SELECT o.outlet_id, o.outlet_name, o.address, o.latitude, o.longitude,
                 o.priority, o.store_type, o.outlet_code, o.credit_limit, o.outstanding as rep_outstanding
          FROM outlet o
          WHERE o.is_active = true
          AND o.outlet_id IN (
            SELECT DISTINCT v.outlet_id FROM visit v
            WHERE v.employee_id = $1
            AND (
              v.visit_date = CURRENT_DATE
              AND v.status IN ('Planned', 'InProgress', 'Completed')
              OR v.status IN ('Planned', 'InProgress')
            )
          )
          ORDER BY o.priority ASC, o.outlet_name ASC`;
        params = [repId];
      }
    } else {
      query = `
        SELECT o.outlet_id, o.outlet_name, o.address, o.latitude, o.longitude,
               o.priority, o.store_type, o.outlet_code, o.credit_limit, o.outstanding as rep_outstanding
        FROM outlet o
        WHERE o.is_active = true
        ORDER BY o.priority ASC, o.outlet_name ASC`;
    }

    const result = await pool.query(query, params);
    res.json(result.rows);
  } catch (err) {
    console.error('Error fetching outlets:', err);
    res.status(500).json({ error: err.message });
  }
});

app.post('/api/outlets', authenticate, authorize('admin', 'manager'), async (req, res) => {
  const { outlet_code, outlet_name, address, latitude, longitude, owner_name, phone, credit_limit, priority, store_type } = req.body;
  if (!outlet_code || !outlet_name || !address) {
    return res.status(400).json({ error: 'Required fields missing' });
  }
  try {
    const result = await pool.query(
      `INSERT INTO outlet (outlet_code, outlet_name, address, latitude, longitude, owner_name, phone, credit_limit, priority, store_type, created_by)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11) RETURNING outlet_id`,
      [outlet_code, outlet_name, address, latitude, longitude, owner_name, phone, credit_limit || 0, priority || 'C', store_type, req.user.employee_id]
    );
    res.status(201).json({ success: true, outlet_id: result.rows[0].outlet_id });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.put('/api/outlets/:id', authenticate, authorize('admin', 'manager'), async (req, res) => {
  const { outlet_name, address, latitude, longitude, owner_name, phone, credit_limit, priority, store_type } = req.body;
  try {
    await pool.query(
      `UPDATE outlet SET outlet_name=$1, address=$2, latitude=$3, longitude=$4, owner_name=$5, phone=$6, credit_limit=$7, priority=$8, store_type=$9
       WHERE outlet_id=$10`,
      [outlet_name, address, latitude, longitude, owner_name, phone, credit_limit, priority, store_type, req.params.id]
    );
    res.json({ success: true });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.delete('/api/outlets/:id', authenticate, authorize('admin', 'manager'), async (req, res) => {
  const outletId = parseInt(req.params.id, 10);
  const force = req.query.force === 'true'; // Force delete option
  
  console.log('========================================');
  console.log('🗑️ DELETE OUTLET REQUEST');
  console.log('outletId:', outletId);
  console.log('force:', force);
  console.log('User:', req.user);
  console.log('========================================');
  
  if (!pool) {
    // Mock mode: simulasikan penghapusan
    console.log('⚠️ Mock mode - outlet deleted');
    return res.json({ success: true, message: 'Outlet deactivated (mock)' });
  }
  
  try {
    // Cek apakah outlet ada
    const outletCheck = await pool.query(
      `SELECT outlet_id, outlet_name, is_active FROM outlet WHERE outlet_id = $1`,
      [outletId]
    );
    
    if (outletCheck.rows.length === 0) {
      console.log('❌ Outlet not found:', outletId);
      return res.status(404).json({ error: 'Outlet not found' });
    }
    
    const outlet = outletCheck.rows[0];
    console.log('📍 Outlet found:', outlet.outlet_name, 'is_active:', outlet.is_active);
    
    // Cek apakah outlet memiliki visit aktif
    const visitCheck = await pool.query(
      `SELECT COUNT(*) as count FROM visit WHERE outlet_id = $1 AND status IN ('Planned', 'InProgress')`,
      [outletId]
    );
    
    const activeVisits = parseInt(visitCheck.rows[0].count);
    console.log('📋 Active visits:', activeVisits);
    
    if (activeVisits > 0 && !force) {
      console.log('⚠️ Cannot delete outlet with active visits (use force=true to override)');
      return res.status(400).json({ 
        error: 'Cannot delete outlet with active visit plans. Please complete or cancel the visits first, or use force=true to cancel them automatically.',
        active_visits: activeVisits,
        suggestion: 'Add ?force=true to the request to cancel active visits and delete the outlet'
      });
    }
    
    // Jika force=true, cancel semua visit aktif
    if (activeVisits > 0 && force) {
      console.log('🔧 Force delete: canceling active visits...');
      const cancelResult = await pool.query(
        `UPDATE visit SET status = 'Missed' WHERE outlet_id = $1 AND status IN ('Planned', 'InProgress') RETURNING COUNT(*) as count`,
        [outletId]
      );
      console.log('✅ Visits canceled:', cancelResult.rows[0].count);
    }
    
    // Soft-delete outlet
    const updateResult = await pool.query(
      `UPDATE outlet SET is_active = false WHERE outlet_id = $1 RETURNING outlet_id, outlet_name`,
      [outletId]
    );
    
    console.log('✅ Outlet deactivated:', updateResult.rows[0]);
    
    // Nonaktifkan semua assignment sales ke outlet ini
    // supaya sales tidak lagi melihat outlet yang sudah dihapus
    const ready = await tablesReady();
    if (ready.assignment) {
      const assignmentResult = await pool.query(
        `UPDATE outlet_assignment SET is_active = false WHERE outlet_id = $1 RETURNING COUNT(*) as count`,
        [outletId]
      );
      console.log('📝 Assignments deactivated:', assignmentResult.rows[0].count);
    }
    
    res.json({ 
      success: true, 
      message: force && activeVisits > 0 
        ? 'Outlet deactivated and active visits canceled' 
        : 'Outlet deactivated successfully',
      outlet: updateResult.rows[0],
      visits_canceled: force && activeVisits > 0 ? activeVisits : 0
    });
  } catch (err) {
    console.error('❌ Error deleting outlet:', err);
    res.status(500).json({ error: err.message });
 }
});

// =====================================================
// GEOFENCES, ROUTE
// =====================================================
app.get('/api/geofences', authenticate, async (req, res) => {
  const role = req.user.role;
  const repId = role === 'rep' ? req.user.employee_id : (req.query.rep_id ? parseInt(req.query.rep_id, 10) : null);

  if (!pool) return res.json([{ id: 1, name: "Toko Maju Jaya", lat: -6.2088, lng: 106.8456, radius: 50 }]);

  try {
    let query;
    let params = [];
    const ready = await tablesReady();

    if (repId) {
      if (ready.assignment) {
        query = `
          SELECT DISTINCT o.outlet_id as id, o.outlet_name as name, o.latitude as lat, o.longitude as lng, 50 as radius
          FROM outlet o
          WHERE o.latitude IS NOT NULL AND o.is_active = TRUE
          AND (
            o.outlet_id IN (
              SELECT oa.outlet_id FROM outlet_assignment oa
              WHERE oa.employee_id = $1 AND oa.is_active = TRUE
            )
            OR o.outlet_id IN (
              SELECT v.outlet_id FROM visit v
              WHERE v.employee_id = $1 AND v.visit_date = CURRENT_DATE
              AND v.status IN ('Planned', 'InProgress', 'Completed')
            )
          )
          ORDER BY o.outlet_name`;
      } else {
        query = `
          SELECT o.outlet_id as id, o.outlet_name as name, o.latitude as lat, o.longitude as lng, 50 as radius
          FROM outlet o
          INNER JOIN visit v ON v.outlet_id = o.outlet_id
          WHERE v.employee_id = $1 AND v.visit_date = CURRENT_DATE
          AND v.status IN ('Planned', 'InProgress', 'Completed')
          AND o.latitude IS NOT NULL
          ORDER BY v.visit_time`;
      }
      params = [repId];
    } else {
      query = `
        SELECT outlet_id as id, outlet_name as name, latitude as lat, longitude as lng, 50 as radius
        FROM outlet WHERE is_active = true AND latitude IS NOT NULL
        ORDER BY outlet_name
      `;
    }

    const result = await pool.query(query, params);
    res.json(result.rows);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});


app.get('/api/route', authenticate, async (req, res) => {
  const role = req.user.role;
  const repId = role === 'rep' ? req.user.employee_id : (req.query.rep_id ? parseInt(req.query.rep_id, 10) : null);

  if (!pool) return res.json([{ latitude: -6.2088, longitude: 106.8456 }]);

  try {
    let query;
    let params = [];

    if (repId) {
      query = `
        SELECT o.latitude, o.longitude
        FROM outlet o
        INNER JOIN visit v ON v.outlet_id = o.outlet_id
        WHERE v.employee_id = $1
        AND v.visit_date = CURRENT_DATE
        AND v.status IN ('Planned', 'InProgress', 'Completed')
        AND o.latitude IS NOT NULL
        ORDER BY v.visit_time
      `;
      params = [repId];
    } else {
      query = `
        SELECT latitude, longitude FROM outlet
        WHERE is_active = true AND latitude IS NOT NULL
        ORDER BY outlet_id
      `;
    }

    const result = await pool.query(query, params);
    res.json(result.rows.map(row => ({
      latitude: parseFloat(row.latitude),
      longitude: parseFloat(row.longitude),
    })));
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});


// =====================================================
// PRODUCTS
// =====================================================
app.get('/api/products', authenticate, async (req, res) => {
  const employeeId = resolveRepId(req);

  if (!pool) {
    return res.json([
      { product_id: 1, product_code: 'EM-250-RED', product_name: 'EnergiMax Drink 250ml', price: 15000, stock: 25, van_stock: 25, unit_name: 'Pcs' },
      { product_id: 2, product_code: 'HP-VITC-100', product_name: 'HealthPlus Vitamin C', price: 45000, stock: 12, van_stock: 12, unit_name: 'Pcs' },
      { product_id: 3, product_code: 'AP-600-BLUE', product_name: 'AquaPure Water 600ml', price: 8500, stock: 5, van_stock: 5, unit_name: 'Pcs' },
      { product_id: 4, product_code: 'ST-CHIPS-150', product_name: 'SnackTime Chips 150g', price: 12500, stock: 18, van_stock: 18, unit_name: 'Pcs' }
    ]);
  }
  try {
    const result = await pool.query(
      `SELECT p.product_id, p.product_code, p.product_name, p.price::numeric as price,
              COALESCE(s.quantity, 0) as van_stock,
              COALESCE(s.quantity, 0) as stock,
              COALESCE(u.unit_name, 'Pcs') as unit_name
       FROM product p
       LEFT JOIN unit u ON u.unit_id = p.unit_id
       LEFT JOIN stock s ON s.product_id = p.product_id
         AND s.employee_id = $1 AND s.type = 'van'
       WHERE p.is_active = true
       ORDER BY p.product_name`,
      [employeeId]
    );
    res.json(result.rows.map((row) => ({
      ...row,
      price: parseFloat(row.price),
      stock: parseInt(row.stock, 10),
      van_stock: parseInt(row.van_stock, 10),
    })));
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// =====================================================
// ORDERS
// =====================================================
app.get('/api/orders', authenticate, async (req, res) => {
  const employeeId = req.user.employee_id;
  const role = req.user.role;

  if (!pool) {
    return res.json([
      { order_id: 1, order_number: 'SO-001', outlet_name: 'Toko Maju Jaya', total: 330000, order_date: new Date().toISOString(), status: 'Completed' }
    ]);
  }

  try {
    let query, params;
    if (role === 'rep') {
      query = `
        SELECT so.order_id, so.order_number, so.order_type, o.outlet_name, so.total, so.order_date, so.sync_status as status
        FROM sales_order so JOIN visit v ON v.visit_id = so.visit_id JOIN outlet o ON o.outlet_id = v.outlet_id
        WHERE v.employee_id = $1 ORDER BY so.order_date DESC LIMIT 50
      `;
      params = [employeeId];
    } else {
      query = `
        SELECT so.order_id, so.order_number, o.outlet_name, so.total, so.order_date, so.sync_status as status, e.name as sales_name
        FROM sales_order so JOIN visit v ON v.visit_id = so.visit_id JOIN outlet o ON o.outlet_id = v.outlet_id
        JOIN employee e ON e.employee_id = v.employee_id
        ORDER BY so.order_date DESC LIMIT 100
      `;
      params = [];
    }
    const result = await pool.query(query, params);
    res.json(result.rows);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.post('/api/orders', authenticate, async (req, res) => {
  const { outletId, items, paymentMethod, orderType, promotionId, total } = req.body;
  const employeeId = req.user.employee_id;
  const validTypes = ['Sales', 'Pre-order', 'Return', 'FOC'];
  const type = validTypes.includes(orderType) ? orderType : 'Sales';

  if (!outletId || !items || items.length === 0) {
    return res.status(400).json({ error: 'Data tidak lengkap' });
  }

  // Validate items structure
  if (!items.every(item => item.productId && item.quantity && item.price)) {
    return res.status(400).json({ error: 'Items structure invalid' });
  }

  if (!pool) {
    return res.status(201).json({ success: true, orderNumber: `SO-MOCK-${Date.now()}` });
  }

  const client = await pool.connect();
  try {
    await client.query('BEGIN');

    const outletResult = await client.query(
      `SELECT outlet_id, credit_limit, outstanding, outlet_name FROM outlet WHERE outlet_id = $1 AND is_active = true`,
      [outletId]
    );
    if (outletResult.rows.length === 0) {
      await client.query('ROLLBACK');
      return res.status(404).json({ error: 'Outlet not found' });
    }
    const outlet = outletResult.rows[0];

    let visitResult = await client.query(
      `SELECT visit_id, check_in_time, status FROM visit 
       WHERE employee_id = $1 AND outlet_id = $2 AND visit_date = CURRENT_DATE`,
      [employeeId, outletId]
    );

    let visitId;
    if (visitResult.rows.length === 0) {
      if (type === 'Sales' || type === 'Return') {
        await client.query('ROLLBACK');
        return res.status(400).json({ error: 'Check-in di outlet ini diperlukan sebelum order' });
      }
      const newVisit = await client.query(
        `INSERT INTO visit (employee_id, outlet_id, visit_date, status) 
         VALUES ($1, $2, CURRENT_DATE, 'Planned') RETURNING visit_id`,
        [employeeId, outletId]
      );
      visitId = newVisit.rows[0].visit_id;
    } else {
      visitId = visitResult.rows[0].visit_id;
      if ((type === 'Sales' || type === 'Return') && !visitResult.rows[0].check_in_time) {
        await client.query('ROLLBACK');
        return res.status(400).json({ error: 'Check-in diperlukan sebelum order Sales/Return' });
      }
    }

    const orderNumber = `SO-${Date.now()}`;
    // Use total from frontend if provided, otherwise calculate from items
    let subtotal = total && total > 0 ? total : items.reduce((sum, item) => sum + (item.price * item.quantity), 0);
    if (type === 'Return') {
      subtotal = Math.abs(subtotal);
    }

    let discount = 0;
    if (type === 'FOC') {
      subtotal = items.reduce((sum, item) => sum + (item.price * item.quantity), 0);
      discount = subtotal;
    } else if (promotionId) {
      const promoResult = await client.query(
        `SELECT type, conditions, reward FROM promotion 
         WHERE promotion_id = $1 AND is_active = true 
         AND CURRENT_DATE BETWEEN start_date AND end_date`,
        [promotionId]
      );
      if (promoResult.rows.length > 0) {
        const promo = promoResult.rows[0];
        const conditions = typeof promo.conditions === 'string'
          ? JSON.parse(promo.conditions)
          : promo.conditions;
        const reward = typeof promo.reward === 'string'
          ? JSON.parse(promo.reward)
          : promo.reward;
        if (promo.type === 'Value-based' && conditions?.min_value) {
          if (subtotal >= conditions.min_value) {
            discount = reward?.discount_amount
              || subtotal * (reward?.discount_percent || 0) / 100;
          }
        }
      }
    }

    const tax = type === 'FOC' ? 0 : (subtotal - discount) * 0.10;
    let finalTotal = type === 'FOC' ? 0 : subtotal - discount + tax;
    if (type === 'Return') {
      finalTotal = subtotal;
    }

    const ready = await tablesReady();

    if (type === 'Sales') {
      for (const item of items) {
        const stockRow = await client.query(
          `SELECT s.quantity, p.product_name FROM stock s
           JOIN product p ON p.product_id = s.product_id
           WHERE s.product_id = $1 AND s.employee_id = $2 AND s.type = 'van'`,
          [item.productId, employeeId]
        );
        const available = stockRow.rows[0]?.quantity ?? 0;
        if (available < item.quantity) {
          await client.query('ROLLBACK');
          const name = stockRow.rows[0]?.product_name || `Produk #${item.productId}`;
          return res.status(400).json({
            error: `Stok van tidak cukup untuk ${name} (tersedia: ${available}, diminta: ${item.quantity})`,
          });
        }
      }
    }

    if (['Sales', 'Pre-order'].includes(type)) {
      let currentOutstanding = parseFloat(outlet.outstanding);
      if (ready.balance) {
        const bal = await client.query(
          `SELECT COALESCE(outstanding, 0) as outstanding FROM outlet_rep_balance
           WHERE outlet_id = $1 AND employee_id = $2`,
          [outletId, employeeId]
        );
        currentOutstanding = parseFloat(bal.rows[0]?.outstanding || 0);
      }
      const projectedOutstanding = currentOutstanding + finalTotal;
      const creditLimit = parseFloat(outlet.credit_limit);
      if (creditLimit > 0 && projectedOutstanding > creditLimit) {
        await client.query('ROLLBACK');
        return res.status(400).json({
          error: 'Melebihi credit limit outlet',
          credit_limit: creditLimit,
          outstanding: currentOutstanding,
          order_total: finalTotal,
          available_credit: creditLimit - currentOutstanding,
        });
      }
    }

    const orderResult = await client.query(
      `INSERT INTO sales_order (order_number, visit_id, order_type, subtotal, discount, tax, total, sync_status) 
       VALUES ($1, $2, $3, $4, $5, $6, $7, 'Pending') RETURNING order_id`,
      [orderNumber, visitId, type, subtotal, discount, tax, finalTotal]
    );
    const orderId = orderResult.rows[0].order_id;

    for (const item of items) {
      await client.query(
        `INSERT INTO order_detail (order_id, product_id, quantity, unit_price) VALUES ($1, $2, $3, $4)`,
        [orderId, item.productId, item.quantity, item.price]
      );

      if (type === 'Sales') {
        await client.query(
          `UPDATE stock SET quantity = GREATEST(0, quantity - $1), last_update = NOW(), updated_by = $2
           WHERE product_id = $3 AND employee_id = $4 AND type = 'van'`,
          [item.quantity, employeeId, item.productId, employeeId]
        );
      } else if (type === 'Return') {
        await client.query(
          `INSERT INTO stock (product_id, employee_id, type, quantity, updated_by)
           VALUES ($1, $2, 'van', $3, $2)
           ON CONFLICT (product_id, type, employee_id)
           DO UPDATE SET quantity = stock.quantity + EXCLUDED.quantity, last_update = NOW(), updated_by = EXCLUDED.updated_by`,
          [item.productId, employeeId, item.quantity]
        );
      }
    }

    if (type === 'Sales' || type === 'Pre-order') {
      if (ready.balance) {
        await client.query(
          `INSERT INTO outlet_rep_balance (outlet_id, employee_id, outstanding)
           VALUES ($1, $2, $3)
           ON CONFLICT (outlet_id, employee_id)
           DO UPDATE SET outstanding = outlet_rep_balance.outstanding + EXCLUDED.outstanding,
                         last_update = CURRENT_TIMESTAMP`,
          [outletId, employeeId, finalTotal]
        );
      }
      await client.query(
        `UPDATE outlet SET outstanding = outstanding + $1 WHERE outlet_id = $2`,
        [finalTotal, outletId]
      );
    } else if (type === 'Return') {
      if (ready.balance) {
        await client.query(
          `INSERT INTO outlet_rep_balance (outlet_id, employee_id, outstanding)
           VALUES ($1, $2, 0)
           ON CONFLICT (outlet_id, employee_id) DO NOTHING`,
          [outletId, employeeId]
        );
        await client.query(
          `UPDATE outlet_rep_balance SET outstanding = GREATEST(0, outstanding - $1), last_update = CURRENT_TIMESTAMP
           WHERE outlet_id = $2 AND employee_id = $3`,
          [finalTotal, outletId, employeeId]
        );
      }
      await client.query(
        `UPDATE outlet SET outstanding = GREATEST(0, outstanding - $1) WHERE outlet_id = $2`,
        [finalTotal, outletId]
      );
    }

    if (ready.assignment) {
      await ensureOutletAssignment(client, outletId, employeeId, employeeId);
    }

    if (visitResult.rows.length > 0 && visitResult.rows[0].status === 'Planned') {
      await client.query(`UPDATE visit SET status = 'InProgress' WHERE visit_id = $1`, [visitId]);
    }

    await client.query('COMMIT');
    res.status(201).json({
      success: true,
      orderNumber,
      orderType: type,
      total: finalTotal,
      outlet_name: outlet.outlet_name,
    });
  } catch (err) {
    await client.query('ROLLBACK');
    res.status(500).json({ error: err.message });
  } finally {
    client.release();
  }
});

// =====================================================
// STOCK MANAGEMENT (DENGAN employee_id - SATU SALES SATU DATA)
// =====================================================

// Get stock (untuk sales rep sendiri atau admin dengan filter rep_id)
app.get('/api/stock', authenticate, async (req, res) => {
  const role = req.user.role;
  const repId = resolveRepId(req);

  if (!pool) {
    if (role === 'rep') {
      return res.json([
        { product_id: 1, product_name: 'EnergiMax Drink 250ml', product_code: 'EM-250-RED', distributor_stock: 420, van_stock: 25, outlet_stock: 15, min_stock: 50, status: 'Good' }
      ]);
    }
    return res.json([]);
  }

  try {
    if (role !== 'rep' && !req.query.rep_id && !req.params.id) {
      return res.status(400).json({
        error: 'Admin/manager harus menyertakan rep_id untuk melihat stok per sales rep',
      });
    }

    const query = `
      SELECT p.product_id, p.product_name, p.product_code, COALESCE(p.min_stock, 0) as min_stock,
      COALESCE((SELECT quantity FROM stock WHERE product_id = p.product_id AND type = 'distributor' AND employee_id = $1), 0) as distributor_stock,
      COALESCE((SELECT quantity FROM stock WHERE product_id = p.product_id AND type = 'van' AND employee_id = $1), 0) as van_stock,
      COALESCE((SELECT quantity FROM stock WHERE product_id = p.product_id AND type = 'outlet' AND employee_id = $1), 0) as outlet_stock,
      CASE 
        WHEN COALESCE((SELECT quantity FROM stock WHERE product_id = p.product_id AND type = 'distributor' AND employee_id = $1), 0) < p.min_stock THEN 'Critical'
        WHEN COALESCE((SELECT quantity FROM stock WHERE product_id = p.product_id AND type = 'van' AND employee_id = $1), 0) < 10 THEN 'Low'
        ELSE 'Good'
      END as status
      FROM product p WHERE p.is_active = true ORDER BY p.product_name`;
    const params = [repId];

    const result = await pool.query(query, params);
    res.json(result.rows);
  } catch (err) {
    console.error('Error fetching stock:', err);
    res.status(500).json({ error: err.message });
  }
});

// Alias untuk kompatibilitas klien lama
app.post('/api/stock/refresh', authenticate, async (req, res) => {
  res.json({ success: true, message: 'Gunakan GET /api/stock untuk data terbaru' });
});

// Download template Excel untuk sales rep tertentu
app.get('/api/admin/sales-reps/:id/stock/download-template', authenticate, authorize('admin', 'manager'), async (req, res) => {
  const repId = req.params.id;
  console.log(`📥 Download template Excel for rep ${repId}`);
  
  try {
    let templateData = [];
    
    if (pool) {
      const products = await pool.query(`
        SELECT product_code, product_name 
        FROM product 
        WHERE is_active = true 
        ORDER BY product_name
      `);
      
      // Template menggunakan kolom yang sesuai dengan struktur data
      templateData = products.rows.map(p => ({
        nama_barang: p.product_name,
        product_code: p.product_code,
        distributor_stock: 0,
        van_stock: 0,
        outlet_stock: 0,
        keterangan: 'Isi kolom stok sesuai lokasi penyimpanan'
      }));
    } else {
      templateData = [
        { nama_barang: 'EnergiMax Drink 250ml', product_code: 'EM-250-RED', distributor_stock: 0, van_stock: 0, outlet_stock: 0, keterangan: 'Isi kolom stok sesuai lokasi penyimpanan' }
      ];
    }
    
    const ws = XLSX.utils.json_to_sheet(templateData);
    const wb = XLSX.utils.book_new();
    XLSX.utils.book_append_sheet(wb, ws, 'Stock Template');
    const buffer = XLSX.write(wb, { type: 'buffer', bookType: 'xlsx' });
    
    res.setHeader('Content-Disposition', `attachment; filename=stock_template_rep_${repId}.xlsx`);
    res.setHeader('Content-Type', 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
    res.send(buffer);
    console.log(`✅ Template Excel downloaded for rep ${repId}`);
  } catch (err) {
    console.error('Error downloading template:', err);
    res.status(500).json({ error: err.message });
  }
});

// Upload Excel untuk sales rep tertentu
app.post('/api/admin/sales-reps/:id/stock/upload-excel', authenticate, authorize('admin', 'manager'), upload.single('file'), async (req, res) => {
  const repId = req.params.id;
  console.log(`📤 Excel upload request for rep ${repId}`);
  console.log(`📁 File info:`, req.file ? {
    originalname: req.file.originalname,
    mimetype: req.file.mimetype,
    size: req.file.size
  } : 'No file');
  console.log(`📋 Headers:`, {
    'content-type': req.get('content-type'),
    'authorization': req.get('authorization') ? 'Bearer ***' : 'No auth'
  });
  
  // Ensure request is multipart/form-data
  if (!req.is('multipart/form-data')) {
    console.log('❌ Not multipart/form-data');
    return res.status(400).json({ error: 'Content-Type must be multipart/form-data' });
  }
  if (!req.file) {
    console.log('❌ No file in request');
    return res.status(400).json({ error: 'File tidak ditemukan' });
  }

  try {
    const workbook = XLSX.read(req.file.buffer, { type: 'buffer' });
    const sheetName = workbook.SheetNames[0];
    const worksheet = workbook.Sheets[sheetName];
    const data = XLSX.utils.sheet_to_json(worksheet);
    
    console.log(`📊 Read ${data.length} rows from Excel`);

    if (data.length === 0) {
      return res.status(400).json({ error: 'File Excel kosong' });
    }

    const firstRow = data[0];
    const hasIdentifier = ['product_code', 'product_name', 'nama_barang', 'nama'].some(col => col in firstRow);
    if (!hasIdentifier) {
      return res.status(400).json({ 
        error: 'Kolom identifikasi produk tidak ditemukan. Pastikan file Excel memiliki kolom "product_code" atau "nama_barang" / "product_name".' 
      });
    }

    let successCount = 0;
    let errorCount = 0;
    const errors = [];

    for (let i = 0; i < data.length; i++) {
      const row = data[i];
      const productCode = row['product_code']?.toString().trim();
      const productNameCol = (row['product_name'] || row['nama_barang'] || row['nama'])?.toString().trim();
      
      let distributorStock = parseInt(row['distributor_stock']) || 0;
      let vanStock = parseInt(row['van_stock']) || 0;
      let outletStock = parseInt(row['outlet_stock']) || 0;

      // Cek apakah user menggunakan kolom total stock umum
      const generalStockVal = row['total_barang'] ?? row['total'] ?? row['stock'] ?? row['quantity'] ?? row['qty'];
      if (generalStockVal !== undefined && !('distributor_stock' in row) && !('van_stock' in row) && !('outlet_stock' in row)) {
        const parsedGeneral = parseInt(generalStockVal) || 0;
        distributorStock = parsedGeneral;
        vanStock = parsedGeneral;
        outletStock = parsedGeneral;
      }

      if (!productCode && !productNameCol) {
        errors.push(`Baris ${i + 2}: Kode produk dan nama produk kosong`);
        errorCount++;
        continue;
      }

      if (!pool) {
        console.log(`Mock update for rep ${repId}: ${productCode || productNameCol} -> D:${distributorStock}, V:${vanStock}, O:${outletStock}`);
        successCount++;
        continue;
      }

      try {
        let productResult;
        if (productCode) {
          productResult = await pool.query(
            `SELECT product_id, product_name FROM product WHERE product_code = $1 AND is_active = true`,
            [productCode]
          );
        } else if (productNameCol) {
          productResult = await pool.query(
            `SELECT product_id, product_name FROM product WHERE LOWER(TRIM(product_name)) = LOWER($1) AND is_active = true`,
            [productNameCol]
          );
        }
        
        if (!productResult || productResult.rows.length === 0) {
          const ident = productCode ? `product_code "${productCode}"` : `nama "${productNameCol}"`;
          errors.push(`Baris ${i + 2}: Produk dengan ${ident} tidak ditemukan`);
          errorCount++;
          continue;
        }
        
        const productId = productResult.rows[0].product_id;
        
        // Update distributor stock (dengan employee_id = repId)
        await pool.query(
          `INSERT INTO stock (product_id, employee_id, type, quantity, updated_by) 
           VALUES ($1, $2, 'distributor', $3, $4)
           ON CONFLICT (product_id, type, employee_id) 
           DO UPDATE SET quantity = EXCLUDED.quantity, last_update = NOW(), updated_by = EXCLUDED.updated_by`,
          [productId, repId, distributorStock, req.user.employee_id]
        );
        
        // Update van stock
        await pool.query(
          `INSERT INTO stock (product_id, employee_id, type, quantity, updated_by) 
           VALUES ($1, $2, 'van', $3, $4)
           ON CONFLICT (product_id, type, employee_id) 
           DO UPDATE SET quantity = EXCLUDED.quantity, last_update = NOW(), updated_by = EXCLUDED.updated_by`,
          [productId, repId, vanStock, req.user.employee_id]
        );
        
        // Update outlet stock
        await pool.query(
          `INSERT INTO stock (product_id, employee_id, type, quantity, updated_by) 
           VALUES ($1, $2, 'outlet', $3, $4)
           ON CONFLICT (product_id, type, employee_id) 
           DO UPDATE SET quantity = EXCLUDED.quantity, last_update = NOW(), updated_by = EXCLUDED.updated_by`,
          [productId, repId, outletStock, req.user.employee_id]
        );
        
        successCount++;
      } catch (err) {
        errors.push(`Baris ${i + 2}: Gagal update stok - ${err.message}`);
        errorCount++;
      }
    }

    console.log(`✅ Excel processed for rep ${repId}: ${successCount} success, ${errorCount} errors`);

    res.json({
      success: true,
      message: `Upload selesai: ${successCount} produk berhasil diupdate, ${errorCount} gagal`,
      successCount: successCount,
      errorCount: errorCount,
      errors: errors.length > 0 ? errors : undefined
    });

  } catch (err) {
    console.error('❌ Error processing Excel:', err);
    res.status(500).json({ error: err.message });
  }
});

// =====================================================
// COLLECTIONS
// =====================================================
app.get('/api/collections/balance', authenticate, async (req, res) => {
  const employeeId = req.user.employee_id;
  const role = req.user.role;

  if (!pool) {
    return res.json({ total_outstanding: 330000 });
  }

  try {
    let query;
    let params = [];
    if (role === 'rep') {
      query = `
        SELECT COALESCE(SUM(so.total - COALESCE(paid.paid_amount, 0)), 0) as total_outstanding
        FROM sales_order so
        JOIN visit v ON v.visit_id = so.visit_id
        LEFT JOIN (
          SELECT order_id, SUM(amount) as paid_amount FROM payment GROUP BY order_id
        ) paid ON paid.order_id = so.order_id
        WHERE v.employee_id = $1
        AND so.total - COALESCE(paid.paid_amount, 0) > 0
      `;
      params = [employeeId];
    } else {
      query = `
        SELECT COALESCE(SUM(so.total - COALESCE(paid.paid_amount, 0)), 0) as total_outstanding
        FROM sales_order so
        LEFT JOIN (
          SELECT order_id, SUM(amount) as paid_amount FROM payment GROUP BY order_id
        ) paid ON paid.order_id = so.order_id
        WHERE so.total - COALESCE(paid.paid_amount, 0) > 0
      `;
    }
    const result = await pool.query(query, params);
    res.json({
      total_outstanding: parseFloat(result.rows[0]?.total_outstanding || 0),
    });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.get('/api/collections/outstanding', authenticate, async (req, res) => {
  const employeeId = req.user.employee_id;
  const role = req.user.role;

  if (!pool) {
    return res.json([
      { order_id: 1, order_number: 'SO-001', outlet_name: 'Toko Maju Jaya', total: 330000, paid_amount: 0, outstanding: 330000, due_date: '2026-05-30', status: 'Pending' }
    ]);
  }

  try {
    let query, params;
    if (role === 'rep') {
      query = `
        SELECT so.order_id, so.order_number, o.outlet_name, so.total, COALESCE(SUM(p.amount), 0) as paid_amount,
        so.total - COALESCE(SUM(p.amount), 0) as outstanding,
        (so.order_date + INTERVAL '30 days')::date as due_date,
        CASE WHEN so.total - COALESCE(SUM(p.amount), 0) <= 0 THEN 'Paid'
             WHEN (so.order_date + INTERVAL '30 days') < NOW() THEN 'Overdue' ELSE 'Pending' END as status
        FROM sales_order so 
        JOIN visit v ON v.visit_id = so.visit_id 
        JOIN outlet o ON o.outlet_id = v.outlet_id
        LEFT JOIN payment p ON p.order_id = so.order_id
        WHERE v.employee_id = $1 
        GROUP BY so.order_id, o.outlet_name
        HAVING so.total - COALESCE(SUM(p.amount), 0) > 0 
        ORDER BY due_date ASC
      `;
      params = [employeeId];
    } else {
      query = `
        SELECT so.order_id, so.order_number, o.outlet_name, so.total, COALESCE(SUM(p.amount), 0) as paid_amount,
        so.total - COALESCE(SUM(p.amount), 0) as outstanding,
        (so.order_date + INTERVAL '30 days')::date as due_date,
        CASE WHEN so.total - COALESCE(SUM(p.amount), 0) <= 0 THEN 'Paid'
             WHEN (so.order_date + INTERVAL '30 days') < NOW() THEN 'Overdue' ELSE 'Pending' END as status
        FROM sales_order so 
        JOIN visit v ON v.visit_id = so.visit_id 
        JOIN outlet o ON o.outlet_id = v.outlet_id
        LEFT JOIN payment p ON p.order_id = so.order_id
        GROUP BY so.order_id, o.outlet_name
        HAVING so.total - COALESCE(SUM(p.amount), 0) > 0 
        ORDER BY due_date ASC
      `;
      params = [];
    }
    const result = await pool.query(query, params);
    res.json(result.rows);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.post('/api/collections/pay', authenticate, async (req, res) => {
  const { orderId, amount, paymentMethod, referenceNumber } = req.body;
  const employeeId = req.user.employee_id;

  if (!orderId || !amount || amount <= 0) {
    return res.status(400).json({ error: 'Invalid payment data' });
  }

  if (!pool) {
    return res.json({ success: true, referenceNumber: `REF-${Date.now()}` });
  }

  try {
    if (req.user.role === 'rep') {
      const owned = await pool.query(
        `SELECT so.order_id FROM sales_order so
         JOIN visit v ON v.visit_id = so.visit_id
         WHERE so.order_id = $1 AND v.employee_id = $2`,
        [orderId, employeeId]
      );
      if (owned.rows.length === 0) {
        return res.status(403).json({ error: 'Order tidak ditemukan untuk akun ini' });
      }
    }

    const orderInfo = await pool.query(
      `SELECT v.outlet_id, v.employee_id, so.total,
              COALESCE((SELECT SUM(amount) FROM payment WHERE order_id = so.order_id), 0) as paid_before
       FROM sales_order so
       JOIN visit v ON v.visit_id = so.visit_id
       WHERE so.order_id = $1`,
      [orderId]
    );
    if (orderInfo.rows.length === 0) {
      return res.status(404).json({ error: 'Order not found' });
    }
    const { outlet_id: outletId, employee_id: orderEmployeeId, total, paid_before: paidBefore } = orderInfo.rows[0];
    const remaining = parseFloat(total) - parseFloat(paidBefore);
    if (amount > remaining + 0.01) {
      return res.status(400).json({
        error: 'Jumlah pembayaran melebihi sisa tagihan',
        remaining,
      });
    }

    const client = await pool.connect();
    try {
      await client.query('BEGIN');
      const refNum = referenceNumber || `REF-${Date.now()}`;
      const result = await client.query(
        `INSERT INTO payment (order_id, amount, payment_method, reference_number, sync_status, recorded_by)
         VALUES ($1, $2, $3, $4, 'Synced', $5) RETURNING payment_id, reference_number`,
        [orderId, amount, paymentMethod, refNum, employeeId]
      );

      const ready = await tablesReady();
      if (ready.balance) {
        await client.query(
          `UPDATE outlet_rep_balance SET outstanding = GREATEST(0, outstanding - $1), last_update = CURRENT_TIMESTAMP
           WHERE outlet_id = $2 AND employee_id = $3`,
          [amount, outletId, orderEmployeeId]
        );
      }
      await client.query(
        `UPDATE outlet SET outstanding = GREATEST(0, outstanding - $1) WHERE outlet_id = $2`,
        [amount, outletId]
      );
      await client.query('COMMIT');

      res.json({
        success: true,
        paymentId: result.rows[0].payment_id,
        referenceNumber: result.rows[0].reference_number,
        remaining: Math.max(0, remaining - amount),
      });
    } catch (payErr) {
      await client.query('ROLLBACK');
      throw payErr;
    } finally {
      client.release();
    }
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.get('/api/collections/history', authenticate, async (req, res) => {
  const employeeId = req.user.employee_id;
  const role = req.user.role;

  if (!pool) return res.json([]);

  try {
    let query, params;
    if (role === 'rep') {
      query = `
        SELECT p.payment_id, p.order_id, p.amount, p.payment_method, p.payment_date, p.reference_number
        FROM payment p 
        JOIN sales_order so ON so.order_id = p.order_id 
        JOIN visit v ON v.visit_id = so.visit_id
        WHERE v.employee_id = $1 
        ORDER BY p.payment_date DESC LIMIT 50
      `;
      params = [employeeId];
    } else {
      query = `SELECT payment_id, order_id, amount, payment_method, payment_date, reference_number FROM payment ORDER BY payment_date DESC LIMIT 100`;
      params = [];
    }
    const result = await pool.query(query, params);
    res.json(result.rows);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// =====================================================
// PROMOTIONS
// =====================================================
app.get('/api/promotions', authenticate, async (req, res) => {
  if (!pool) {
    return res.json([]);
  }
  try {
    const activeOnly = req.query.active === 'true';
    let query = `SELECT promotion_id, promotion_code, description, type, conditions, reward, start_date, end_date, is_active
                 FROM promotion`;
    if (activeOnly) {
      query += ` WHERE is_active = true AND CURRENT_DATE BETWEEN start_date AND end_date`;
    }
    query += ` ORDER BY start_date DESC`;
    const result = await pool.query(query);
    res.json(result.rows);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.post('/api/promotions', authenticate, authorize('admin', 'manager'), async (req, res) => {
  const { promotion_code, description, type, conditions, reward, start_date, end_date } = req.body;
  if (!promotion_code || !type || !start_date || !end_date) {
    return res.status(400).json({ error: 'Missing required fields' });
  }
  try {
    const result = await pool.query(
      `INSERT INTO promotion (promotion_code, description, type, conditions, reward, start_date, end_date, created_by)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8) RETURNING promotion_id`,
      [
        promotion_code,
        description,
        type,
        JSON.stringify(conditions || {}),
        JSON.stringify(reward || {}),
        start_date,
        end_date,
        req.user.employee_id,
      ]
    );
    res.status(201).json({ success: true, promotion_id: result.rows[0].promotion_id });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.put('/api/promotions/:id', authenticate, authorize('admin', 'manager'), async (req, res) => {
  const { description, type, conditions, reward, start_date, end_date, is_active } = req.body;
  if (!pool) {
    return res.json({ success: true, message: 'Promotion updated (mock)' });
  }
  try {
    await pool.query(
      `UPDATE promotion SET description=$1, type=$2, conditions=$3, reward=$4, start_date=$5, end_date=$6, is_active=$7
       WHERE promotion_id=$8`,
      [
        description,
        type,
        JSON.stringify(conditions || {}),
        JSON.stringify(reward || {}),
        start_date,
        end_date,
        is_active !== undefined ? is_active : true,
        req.params.id,
      ]
    );
    res.json({ success: true });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Hapus / nonaktifkan promotion
app.delete('/api/promotions/:id', authenticate, authorize('admin', 'manager'), async (req, res) => {
  if (!pool) {
    return res.json({ success: true, message: 'Promotion deleted (mock)' });
  }
  try {
    await pool.query(
      `UPDATE promotion SET is_active = false WHERE promotion_id = $1`,
      [req.params.id]
    );
    res.json({ success: true });
  } catch (err) {
    console.error('Error deleting promotion:', err);
    res.status(500).json({ error: err.message });
  }
});

// =====================================================
// MERCHANDISING AUDIT
// =====================================================
app.post('/api/merchandising', authenticate, async (req, res) => {
  const { visitId, planogram_score, shelf_share, posm_placement, notes } = req.body;
  const employeeId = req.user.employee_id;

  if (!visitId) {
    return res.status(400).json({ error: 'visitId required' });
  }

  if (!pool) {
    return res.json({ success: true, message: 'Audit saved (mock)' });
  }

  try {
    const visitCheck = await pool.query(
      `SELECT visit_id FROM visit WHERE visit_id = $1 AND employee_id = $2`,
      [visitId, employeeId]
    );
    if (visitCheck.rows.length === 0 && req.user.role === 'rep') {
      return res.status(403).json({ error: 'Visit not found for this user' });
    }

    const result = await pool.query(
      `INSERT INTO merchandising_audit (visit_id, planogram_score, shelf_share, posm_placement, notes)
       VALUES ($1, $2, $3, $4, $5)
       ON CONFLICT (visit_id) DO UPDATE SET
         planogram_score = EXCLUDED.planogram_score,
         shelf_share = EXCLUDED.shelf_share,
         posm_placement = EXCLUDED.posm_placement,
         notes = EXCLUDED.notes
       RETURNING audit_id`,
      [visitId, planogram_score, shelf_share, posm_placement || false, notes]
    );
    res.status(201).json({ success: true, audit_id: result.rows[0].audit_id });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.get('/api/merchandising/:visitId', authenticate, async (req, res) => {
  if (!pool) return res.json(null);
  try {
    if (req.user.role === 'rep') {
      const owned = await pool.query(
        `SELECT visit_id FROM visit WHERE visit_id = $1 AND employee_id = $2`,
        [req.params.visitId, req.user.employee_id]
      );
      if (owned.rows.length === 0) {
        return res.status(403).json({ error: 'Visit not found for this user' });
      }
    }
    const result = await pool.query(
      `SELECT * FROM merchandising_audit WHERE visit_id = $1`,
      [req.params.visitId]
    );
    res.json(result.rows[0] || null);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// =====================================================
// VISITS (list, missed, reschedule)
// =====================================================
app.get('/api/visits/today', authenticate, async (req, res) => {
  const employeeId = req.user.employee_id;
  const role = req.user.role;
  const repId = req.query.rep_id ? parseInt(req.query.rep_id, 10) : employeeId;

  if (!pool) {
    return res.json([]);
  }

  try {
    let query;
    let params;

    if (role === 'rep') {
      query = `
        SELECT v.visit_id, v.outlet_id, o.outlet_name, o.address, v.visit_time, v.status,
               v.check_in_time, v.check_out_time, v.visit_reason, o.priority
        FROM visit v
        JOIN outlet o ON o.outlet_id = v.outlet_id
        WHERE v.employee_id = $1 AND v.visit_date = CURRENT_DATE
        ORDER BY v.visit_time
      `;
      params = [employeeId];
    } else {
      query = `
        SELECT v.visit_id, v.outlet_id, o.outlet_name, o.address, v.visit_time, v.status,
               v.check_in_time, v.check_out_time, v.visit_reason, o.priority, e.name as sales_name
        FROM visit v
        JOIN outlet o ON o.outlet_id = v.outlet_id
        JOIN employee e ON e.employee_id = v.employee_id
        WHERE v.employee_id = $1 AND v.visit_date = CURRENT_DATE
        ORDER BY v.visit_time
      `;
      params = [repId];
    }

    const result = await pool.query(query, params);
    res.json(result.rows);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.post('/api/visits/:id/missed', authenticate, async (req, res) => {
  const { reason } = req.body;
  const visitId = req.params.id;
  const employeeId = req.user.employee_id;

  if (!pool) {
    return res.json({ success: true });
  }

  try {
    const result = await pool.query(
      `UPDATE visit SET status = 'Missed', visit_reason = $1, notes = $2
       WHERE visit_id = $3 AND employee_id = $4
       RETURNING visit_id`,
      [reason || 'Missed', reason, visitId, employeeId]
    );
    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Visit not found' });
    }
    res.json({ success: true, message: 'Visit marked as missed' });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.post('/api/visits/:id/reschedule', authenticate, authorize('admin', 'manager', 'rep'), async (req, res) => {
  const { visit_date, visit_time } = req.body;
  const visitId = req.params.id;

  if (!visit_date) {
    return res.status(400).json({ error: 'visit_date required' });
  }

  if (!pool) {
    return res.json({ success: true });
  }

  try {
    let result;
    if (req.user.role === 'rep') {
      result = await pool.query(
        `UPDATE visit SET visit_date = $1, visit_time = COALESCE($2, visit_time), status = 'Planned'
         WHERE visit_id = $3 AND employee_id = $4 RETURNING visit_id`,
        [visit_date, visit_time, visitId, req.user.employee_id]
      );
    } else {
      result = await pool.query(
        `UPDATE visit SET visit_date = $1, visit_time = COALESCE($2, visit_time), status = 'Planned'
         WHERE visit_id = $3 RETURNING visit_id`,
        [visit_date, visit_time, visitId]
      );
    }
    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Visit not found' });
    }
    res.json({ success: true, message: 'Visit rescheduled' });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// =====================================================
// SUPERVISOR DASHBOARD
// =====================================================
app.get('/api/supervisor/team-dashboard', authenticate, authorize('supervisor', 'manager', 'admin'), async (req, res) => {
  let teamManagerId = req.user.employee_id;

  if (!pool) {
    return res.json({ team: [], members: [] });
  }

  try {
    if (req.user.role === 'supervisor') {
      const supRow = await pool.query(
        `SELECT manager_id FROM user_account WHERE employee_id = $1`,
        [req.user.employee_id]
      );
      if (supRow.rows[0]?.manager_id) {
        teamManagerId = supRow.rows[0].manager_id;
      }
    }

    const teamResult = await pool.query(
      `SELECT t.team_id, t.team_name FROM team t WHERE t.manager_id = $1 LIMIT 1`,
      [teamManagerId]
    );

    const membersResult = await pool.query(
      `SELECT e.employee_id, e.name, e.email,
              COUNT(DISTINCT v.visit_id) as total_visits,
              COUNT(DISTINCT CASE WHEN v.status = 'Completed' THEN v.visit_id END) as completed_visits,
              COUNT(DISTINCT CASE WHEN v.status = 'Missed' THEN v.visit_id END) as missed_visits,
              COUNT(DISTINCT so.order_id) as total_orders,
              COALESCE(SUM(so.total), 0) as total_sales
       FROM team_member tm
       JOIN team t ON t.team_id = tm.team_id
       JOIN employee e ON e.employee_id = tm.employee_id
       LEFT JOIN visit v ON v.employee_id = e.employee_id AND v.visit_date = CURRENT_DATE
       LEFT JOIN sales_order so ON so.visit_id = v.visit_id
       WHERE t.manager_id = $1
       GROUP BY e.employee_id, e.name, e.email
       ORDER BY e.name`,
      [teamManagerId]
    );

    res.json({
      team: teamResult.rows[0] || null,
      members: membersResult.rows,
    });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// =====================================================
// PRODUCTS ADMIN
// =====================================================
app.post('/api/products', authenticate, authorize('admin', 'manager'), async (req, res) => {
  const { product_code, product_name, product_type, unit_id, min_stock, price } = req.body;
  if (!product_code || !product_name || !price) {
    return res.status(400).json({ error: 'Missing required fields' });
  }
  try {
    const result = await pool.query(
      `INSERT INTO product (product_code, product_name, product_type, unit_id, min_stock, price, created_by)
       VALUES ($1, $2, $3, $4, $5, $6, $7) RETURNING product_id`,
      [
        product_code,
        product_name,
        product_type || 'Finished Goods',
        unit_id || 1,
        min_stock || 0,
        price,
        req.user.employee_id,
      ]
    );
    res.status(201).json({ success: true, product_id: result.rows[0].product_id });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.put('/api/products/:id', authenticate, authorize('admin', 'manager'), async (req, res) => {
  const { product_name, product_type, min_stock, price, is_active } = req.body;
  try {
    await pool.query(
      `UPDATE product SET product_name=$1, product_type=$2, min_stock=$3, price=$4, is_active=$5
       WHERE product_id=$6`,
      [product_name, product_type, min_stock, price, is_active !== false, req.params.id]
    );
    res.json({ success: true });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// =====================================================
// ANALYTICS (per user / sales rep)
// =====================================================

function resolveAnalyticsEmployeeId(req) {
  return resolveRepId(req);
}

app.get('/api/analytics/daily-sales', authenticate, async (req, res) => {
  const employeeId = resolveAnalyticsEmployeeId(req);
  const days = parseInt(req.query.days, 10) || 7;

  if (!pool) {
    // Mock data bermakna: simulasi penjualan 7 hari terakhir
    const mockData = [];
    for (let i = days - 1; i >= 0; i--) {
      const d = new Date();
      d.setDate(d.getDate() - i);
      const totalSales = Math.floor(Math.random() * 5000000) + 1000000;
      const totalOrders = Math.floor(Math.random() * 10) + 1;
      const totalVisits = Math.floor(Math.random() * 15) + 5;
      const strikeRate = totalVisits > 0 ? Math.round((totalOrders / totalVisits) * 100) : 0;
      mockData.push({
        date: d.toISOString().split('T')[0],
        total_sales: totalSales,
        total_orders: totalOrders,
        total_visits: totalVisits,
        strike_rate: strikeRate,
      });
    }
    return res.json(mockData);
  }

  try {
    const result = await pool.query(
      `SELECT 
         DATE(so.order_date) as date, 
         COALESCE(SUM(so.total), 0) as total_sales,
         COUNT(DISTINCT so.order_id) as total_orders,
         COUNT(DISTINCT v.visit_id) as total_visits,
         CASE 
           WHEN COUNT(DISTINCT v.visit_id) > 0 
           THEN ROUND((COUNT(DISTINCT so.order_id)::numeric / COUNT(DISTINCT v.visit_id)) * 100, 2)
           ELSE 0 
         END as strike_rate
       FROM sales_order so
       JOIN visit v ON v.visit_id = so.visit_id
       WHERE v.employee_id = $1 AND v.visit_date >= CURRENT_DATE - ($2 || ' days')::INTERVAL
       GROUP BY DATE(so.order_date)
       ORDER BY date ASC`,
      [employeeId, days]
    );
    res.json(result.rows);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.get('/api/analytics/top-products', authenticate, async (req, res) => {
  const employeeId = resolveAnalyticsEmployeeId(req);
  const limit = parseInt(req.query.limit, 10) || 5;

  if (!pool) {
    return res.json([
      { product_name: 'EnergiMax 250ml', total_quantity: 120, total_sales: 3600000 },
      { product_name: 'EnergiMax 500ml', total_quantity: 85, total_sales: 4250000 },
      { product_name: 'IsoPlus Sport', total_quantity: 60, total_sales: 2400000 },
      { product_name: 'AquaFresh', total_quantity: 45, total_sales: 900000 },
      { product_name: 'VitaBoost', total_quantity: 30, total_sales: 1500000 },
    ].slice(0, limit));
  }

  try {
    const result = await pool.query(
      `SELECT p.product_name, SUM(od.quantity) as total_quantity,
              SUM(od.quantity * od.unit_price) as total_sales
       FROM order_detail od
       JOIN sales_order so ON so.order_id = od.order_id
       JOIN visit v ON v.visit_id = so.visit_id
       JOIN product p ON p.product_id = od.product_id
       WHERE v.employee_id = $1
       GROUP BY p.product_name
       ORDER BY total_sales DESC
       LIMIT $2`,
      [employeeId, limit]
    );
    res.json(result.rows);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.get('/api/analytics/top-outlets', authenticate, async (req, res) => {
  const employeeId = resolveAnalyticsEmployeeId(req);
  const limit = parseInt(req.query.limit, 10) || 5;

  if (!pool) {
    return res.json([
      { outlet_name: 'Toko Maju Jaya', total_visits: 15, total_sales: 4500000 },
      { outlet_name: 'Toko Sejahtera', total_visits: 10, total_sales: 3200000 },
      { outlet_name: 'Toko Makmur Abadi', total_visits: 8, total_sales: 2100000 },
      { outlet_name: 'Toko Baru Jaya', total_visits: 5, total_sales: 1500000 },
    ].slice(0, limit));
  }

  try {
    const result = await pool.query(
      `SELECT o.outlet_name, COUNT(DISTINCT v.visit_id) as total_visits,
              COALESCE(SUM(so.total), 0) as total_sales
       FROM visit v
       JOIN outlet o ON o.outlet_id = v.outlet_id
       LEFT JOIN sales_order so ON so.visit_id = v.visit_id
       WHERE v.employee_id = $1
       GROUP BY o.outlet_name
       ORDER BY total_sales DESC
       LIMIT $2`,
      [employeeId, limit]
    );
    res.json(result.rows);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.get('/api/analytics/summary', authenticate, async (req, res) => {
  const employeeId = resolveAnalyticsEmployeeId(req);

  if (!pool) {
    // Mock data bermakna
    return res.json({
      total_sales: 15750000,
      total_orders: 42,
      total_visits: 67,
      strike_rate: 62.7,
    });
  }

  try {
    const result = await pool.query(
      `SELECT
         COALESCE(SUM(so.total), 0) as total_sales,
         COUNT(DISTINCT so.order_id) as total_orders,
         COUNT(DISTINCT v.visit_id) as total_visits,
         CASE WHEN COUNT(DISTINCT v.visit_id) > 0
           THEN (COUNT(DISTINCT CASE WHEN so.order_id IS NOT NULL THEN v.visit_id END)::float
                 / COUNT(DISTINCT v.visit_id)) * 100
           ELSE 0 END as strike_rate
       FROM visit v
       LEFT JOIN sales_order so ON so.visit_id = v.visit_id
       WHERE v.employee_id = $1 AND v.visit_date >= CURRENT_DATE - INTERVAL '30 days'`,
      [employeeId]
    );
    res.json(result.rows[0] || {
      total_sales: 0,
      total_orders: 0,
      total_visits: 0,
      strike_rate: 0,
    });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// =====================================================
// VISITS (Check-in/out)
// =====================================================
app.post('/api/visits/checkin', authenticate, async (req, res) => {
  const { outletId, latitude, longitude, visitReason } = req.body;
  const employeeId = req.user.employee_id;

  if (!outletId || !latitude || !longitude) {
    return res.status(400).json({ error: 'Incomplete data' });
  }

  if (!pool) {
    return res.json({ success: true, message: 'Check-in successful (mock)', visitId: 999, distance: 5.2, outletName: "Toko Maju Jaya" });
  }

  try {
    const outletResult = await pool.query(`SELECT latitude, longitude, outlet_name FROM outlet WHERE outlet_id = $1`, [outletId]);
    if (outletResult.rows.length === 0) return res.status(404).json({ error: 'Outlet not found' });

    const outlet = outletResult.rows[0];
    const distance = calculateDistance(latitude, longitude, parseFloat(outlet.latitude), parseFloat(outlet.longitude));
    if (distance > 50) {
      return res.status(400).json({ error: 'Outside geofence', distance, required: 50 });
    }

    const existingVisit = await pool.query(
      `SELECT visit_id FROM visit WHERE employee_id = $1 AND outlet_id = $2 AND visit_date = CURRENT_DATE`,
      [employeeId, outletId]
    );

    let visitId;
    const ready = await tablesReady();
    const client = await pool.connect();
    try {
      await client.query('BEGIN');
      if (existingVisit.rows.length > 0) {
        visitId = existingVisit.rows[0].visit_id;
        await client.query(
          `UPDATE visit SET check_in_time = CURRENT_TIMESTAMP, check_in_lat = $1, check_in_lng = $2, visit_reason = $3, status = 'InProgress' WHERE visit_id = $4`,
          [latitude, longitude, visitReason, visitId]
        );
      } else {
        const result = await client.query(
          `INSERT INTO visit (employee_id, outlet_id, visit_date, check_in_time, check_in_lat, check_in_lng, visit_reason, status)
           VALUES ($1, $2, CURRENT_DATE, CURRENT_TIMESTAMP, $3, $4, $5, 'InProgress') RETURNING visit_id`,
          [employeeId, outletId, latitude, longitude, visitReason]
        );
        visitId = result.rows[0].visit_id;
      }
      if (ready.assignment) {
        await ensureOutletAssignment(client, outletId, employeeId, employeeId);
      }
      await client.query('COMMIT');
    } catch (checkinErr) {
      await client.query('ROLLBACK');
      throw checkinErr;
    } finally {
      client.release();
    }

    res.json({ success: true, message: 'Check-in successful', visitId, distance: distance.toFixed(1), outletName: outlet.outlet_name });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.post('/api/visits/checkout', authenticate, async (req, res) => {
  const { visitId } = req.body;
  const employeeId = req.user.employee_id;

  if (!visitId) return res.status(400).json({ error: 'Visit ID required' });

  if (!pool) return res.json({ success: true, message: 'Check-out successful (mock)' });

  try {
    const result = await pool.query(
      `UPDATE visit SET check_out_time = CURRENT_TIMESTAMP, status = 'Completed' WHERE visit_id = $1 AND employee_id = $2 RETURNING visit_id`,
      [visitId, employeeId]
    );
    if (result.rows.length === 0) return res.status(404).json({ error: 'Visit not found' });
    res.json({ success: true, message: 'Check-out successful' });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Update live location (for sales rep)
app.post('/api/visits/location', authenticate, async (req, res) => {
  const { latitude, longitude } = req.body;
  const employeeId = req.user.employee_id;

  if (latitude === undefined || longitude === undefined) {
    return res.status(400).json({ error: 'Latitude and longitude required' });
  }

  if (!pool) {
    console.log(`Mock live location update for rep ${employeeId}: ${latitude}, ${longitude}`);
    return res.json({ success: true, message: 'Location updated (mock)' });
  }

  try {
    await pool.query(
      `UPDATE employee 
       SET last_lat = $1, last_lng = $2, last_location_update = CURRENT_TIMESTAMP
       WHERE employee_id = $3`,
      [latitude, longitude, employeeId]
    );
    res.json({ success: true, message: 'Location updated successfully' });
  } catch (err) {
    console.error('Error updating live location:', err);
    res.status(500).json({ error: err.message });
  }
});


// =====================================================
// TEAM MANAGEMENT (MANAGER ONLY)
// =====================================================
app.get('/api/team/members', authenticate, authorize('manager', 'admin', 'supervisor'), async (req, res) => {
  const managerId = req.user.employee_id;

  if (!pool) {
    return res.json([
      { employee_id: 3, name: 'Sales Rep A', email: 'rep.a@company.com', role: 'rep', joined_date: '2026-01-01' },
      { employee_id: 4, name: 'Sales Rep B', email: 'rep.b@company.com', role: 'rep', joined_date: '2026-01-15' }
    ]);
  }

  try {
    const result = await pool.query(`
      SELECT e.employee_id, e.name, e.email, e.phone, u.role, tm.joined_date
      FROM team_member tm
      JOIN team t ON t.team_id = tm.team_id
      JOIN employee e ON e.employee_id = tm.employee_id
      JOIN user_account u ON u.employee_id = e.employee_id
      WHERE t.manager_id = $1
      ORDER BY tm.joined_date DESC
    `, [managerId]);
    res.json(result.rows);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.post('/api/team/register', authenticate, authorize('manager', 'admin'), async (req, res) => {
  const { name, email, phone, username, password, role } = req.body;
  const managerId = req.user.employee_id;

  if (!name || !email || !username || !password) {
    return res.status(400).json({ error: 'Missing required fields' });
  }

  if (!pool) {
    return res.status(201).json({ success: true, message: 'Sales rep registered (mock)' });
  }

  const client = await pool.connect();
  try {
    await client.query('BEGIN');

    const hashedPassword = await bcrypt.hash(password, 10);

    const employeeResult = await client.query(
      `INSERT INTO employee (nik, name, email, phone, created_by) VALUES ($1, $2, $3, $4, $5) RETURNING employee_id`,
      [`EMP-${Date.now()}`, name, email, phone, managerId]
    );
    const employeeId = employeeResult.rows[0].employee_id;

    await client.query(
      `INSERT INTO user_account (employee_id, username, password_hash, role, is_verified) VALUES ($1, $2, $3, $4, true)`,
      [employeeId, username, hashedPassword, role || 'rep']
    );

    const teamResult = await client.query(`SELECT team_id FROM team WHERE manager_id = $1`, [managerId]);
    if (teamResult.rows.length > 0) {
      await client.query(
        `INSERT INTO team_member (team_id, employee_id) VALUES ($1, $2)`,
        [teamResult.rows[0].team_id, employeeId]
      );
    }

    await client.query('COMMIT');
    res.status(201).json({ success: true, message: 'Sales representative registered successfully' });
  } catch (err) {
    await client.query('ROLLBACK');
    res.status(500).json({ error: err.message });
  } finally {
    client.release();
  }
});

// =====================================================
// 404 — route tidak dikenal
// =====================================================
app.use((req, res) => {
  res.status(404).json({
    error: 'Route not found',
    method: req.method,
    path: req.url,
    hint: 'Gunakan prefix /api — contoh: GET /api/test',
    coba: `http://localhost:${PORT}/api/test`,
  });
});

// =====================================================
// START SERVER
// =====================================================
const server = app.listen(PORT, '0.0.0.0', () => {
  console.log(`
  ═══════════════════════════════════════════════════════════════════
  🚀 MOBILE SALES CANVASSING API SERVER - FINAL VERSION
  ═══════════════════════════════════════════════════════════════════
  
  📍 Server running at: http://localhost:${PORT}
  🧪 Cek di browser: http://localhost:${PORT}/api/test
  📱 Access from phone: http://[YOUR_IP_ADDRESS]:${PORT}/api
  
  ═══════════════════════════════════════════════════════════════════
  📌 AVAILABLE ENDPOINTS:
  ═══════════════════════════════════════════════════════════════════
  
  🔐 AUTHENTICATION:
     POST   /api/auth/login
     GET    /api/auth/profile (requires token)
  
  👥 ADMIN / MANAGER (Sales Rep Management):
     GET    /api/admin/sales-reps
     GET    /api/admin/sales-reps/:id
     GET    /api/admin/sales-reps/:id/dashboard
     GET    /api/admin/sales-reps/:id/orders
     GET    /api/admin/sales-reps/:id/payments
     GET    /api/admin/sales-reps/:id/analytics
     POST   /api/admin/sales-reps
     PUT    /api/admin/sales-reps/:id
     DELETE /api/admin/sales-reps/:id
     
  🏪 ASSIGN OUTLET TO SALES REP:
     GET    /api/admin/sales-reps/:id/outlets
     GET    /api/admin/sales-reps/:id/available-outlets
     POST   /api/admin/sales-reps/:id/assign-outlet
     DELETE /api/admin/sales-reps/:id/remove-outlet/:outlet_id
  
  📊 DASHBOARD (User view):
     GET    /api/dashboard (requires token)
  
  🏪 OUTLETS:
     GET    /api/outlets (requires token)
     POST   /api/outlets (requires token, admin/manager)
     PUT    /api/outlets/:id (requires token, admin/manager)
     DELETE /api/outlets/:id (requires token, admin/manager)
  
  📍 GPS & ROUTE:
     GET    /api/geofences (requires token)
     GET    /api/route (requires token)
  
  📦 PRODUCTS & ORDERS:
     GET    /api/products (requires token)
     GET    /api/orders (requires token)
     POST   /api/orders (requires token)
  
  📊 STOCK MANAGEMENT (Satu Sales Satu Data):
     GET    /api/stock (requires token)
     GET    /api/admin/sales-reps/:id/stock/download-template (requires token, admin/manager)
     POST   /api/admin/sales-reps/:id/stock/upload-excel (requires token, admin/manager)
  
  💰 COLLECTIONS:
     GET    /api/collections/outstanding (requires token)
     POST   /api/collections/pay (requires token)
     GET    /api/collections/history (requires token)
  
  ✅ VISITS (GPS Check-in/out):
     POST   /api/visits/checkin (requires token)
     POST   /api/visits/checkout (requires token)
  
  👥 TEAM MANAGEMENT (Manager only):
     GET    /api/team/members (requires token, manager/admin)
     POST   /api/team/register (requires token, manager/admin)
  
  🧪 TEST:
     GET    /api/test
  
  ═══════════════════════════════════════════════════════════════════
  `);
});

// Global error handler - return JSON for all errors
app.use((err, req, res, next) => {
  console.error('Error in request:', err);
  
  // Return JSON for all errors instead of HTML
  return res.status(err.status || 500).json({ 
    error: err.message || 'Internal server error'
  });
});

server.on('error', (err) => {
  if (err.code === 'EADDRINUSE') {
    console.error(`\n❌ Port ${PORT} sudah dipakai program lain.`);
    console.error('   Tutup terminal lama yang menjalankan node server.js, atau:');
    console.error('   PowerShell: Get-NetTCPConnection -LocalPort 3000 | Select OwningProcess');
    console.error('   Lalu Task Manager → akhiri proses Node.js yang lama.\n');
  } else {
    console.error('❌ Server gagal start:', err.message);
  }
  process.exit(1);
});