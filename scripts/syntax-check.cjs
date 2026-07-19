#!/usr/bin/env node
/* syntax-check — extract the <script type="module"> block from index.html and run
 * `node --check` on it. No browser, no bundler. Usage: node scripts/syntax-check.cjs */
const fs = require('fs');
const os = require('os');
const cp = require('child_process');
const path = require('path');

const HTML = process.argv[2] || path.join(__dirname, '..', 'index.html');
const src = fs.readFileSync(HTML, 'utf8');
const m = src.match(/<script\s+type=["']module["']\s*>([\s\S]*?)<\/script>/i);
if (!m) { console.error('FAIL: no <script type="module"> block found'); process.exit(2); }

const out = path.join(os.tmpdir(), 'kommilo_module_check.mjs');
fs.writeFileSync(out, m[1]);
try {
  cp.execSync(`node --check "${out}"`, { stdio: 'pipe' });
  console.log('syntax-check: node --check OK (0 syntax errors)');
  process.exit(0);
} catch (e) {
  console.error('syntax-check: FAIL');
  console.error(e.stdout ? e.stdout.toString() : '', e.stderr ? e.stderr.toString() : '');
  process.exit(1);
}
