const bcrypt = require('bcrypt');

async function generateHashes() {
  const hashes = {
    admin: await bcrypt.hash('admin', 10),
    manager: await bcrypt.hash('manager', 10),
    repa: await bcrypt.hash('repa', 10),
    repb: await bcrypt.hash('repb', 10),
    supervisor: await bcrypt.hash('supervisor', 10)
  };
  console.log(JSON.stringify(hashes, null, 2));
}

generateHashes();
