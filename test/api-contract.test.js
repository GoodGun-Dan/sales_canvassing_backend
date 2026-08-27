const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');
const bcrypt = require('bcrypt');

const serverSource = fs.readFileSync(
  path.join(__dirname, '..', 'server.js'),
  'utf8',
);
const schemaSource = fs.readFileSync(
  path.join(__dirname, '..', 'database_schema_fixed.sql'),
  'utf8',
);
const orderScreenSource = fs.readFileSync(
  path.join(__dirname, '..', '..', 'sales_canvassing_app', 'lib', 'screens', 'order_taking_screen.dart'),
  'utf8',
);
const supervisorDashboardSource = fs.readFileSync(
  path.join(__dirname, '..', '..', 'sales_canvassing_app', 'lib', 'screens', 'supervisor_dashboard.dart'),
  'utf8',
);

test('visit permission memakai endpoint yang didukung', () => {
  assert.match(serverSource, /app\.post\('\/api\/visits\/:id\/cancel-permission'/);
  assert.doesNotMatch(serverSource, /request-permission/);
});

test('order menghitung harga di server dan memeriksa assignment', () => {
  assert.match(serverSource, /Outlet is not assigned to this sales rep/);
  assert.match(serverSource, /SELECT product_id, price::numeric AS price FROM product/);
  assert.doesNotMatch(serverSource, /total && total > 0/);
});

test('data master yang dapat diedit tidak hilang dari respons daftar', () => {
  assert.match(serverSource, /o\.owner_name, o\.phone, o\.credit_limit/);
  assert.match(serverSource, /if \(result\.rowCount === 0\) return res\.status\(404\)\.json\(\{ error: 'Outlet not found' \}\)/);
  assert.match(serverSource, /if \(result\.rowCount === 0\) return res\.status\(404\)\.json\(\{ error: 'Product not found' \}\)/);
});

test('FOC memvalidasi dan mengurangi stok van', () => {
  assert.match(serverSource, /if \(type === 'Sales' \|\| type === 'FOC'\) \{[\s\S]*Stok van tidak cukup/);
  assert.match(serverSource, /if \(type === 'Sales' \|\| type === 'FOC'\) \{\s*await client\.query\(/);
});

test('total yang dipreview aplikasi mengikuti aturan diskon server', () => {
  assert.doesNotMatch(orderScreenSource, /return _subtotal \* 0\.05/);
  assert.match(orderScreenSource, /return 0;/);
});

test('dashboard supervisor tidak membuka fitur manager yang ditolak API', () => {
  assert.doesNotMatch(supervisorDashboardSource, /ManagerOutletScreen/);
});

test('admin membuat manager/sales dan manager dibatasi pada team-nya', () => {
  assert.match(serverSource, /app\.post\('\/api\/admin\/managers', authenticate, authorize\('admin'\)/);
  assert.match(serverSource, /app\.post\('\/api\/admin\/sales-reps', authenticate, authorize\('admin', 'manager'\)/);
  assert.doesNotMatch(serverSource, /app\.post\('\/api\/manager\/admins'/);
  assert.match(serverSource, /requireManagedRep/);
  assert.match(serverSource, /requireManagedOutlet/);
  assert.match(serverSource, /app\.post\('\/api\/admin\/sales-reps\/:id\/assign-outlet', authenticate, authorize\('admin', 'manager'\)/);
});

test('reset password menggunakan kode acak kriptografis dan masa berlaku', () => {
  assert.match(serverSource, /crypto\.randomInt\(100000, 1000000\)/);
  assert.match(serverSource, /expires_at > CURRENT_TIMESTAMP/);
});

test('akun demo dari schema dapat dipakai untuk login', async () => {
  const users = [
    ['admin', 'admin'],
    ['manager', 'manager'],
    ['repa', 'repa'],
    ['repb', 'repb'],
    ['supervisor', 'supervisor'],
  ];

  for (const [username, password] of users) {
    const row = schemaSource.match(
      new RegExp(`\\(\\d+, '${username}', '([^']+)'`),
    );
    assert.ok(row, `seed user ${username} must exist`);
    assert.equal(await bcrypt.compare(password, row[1]), true, `${username} password hash is invalid`);
  }
});
