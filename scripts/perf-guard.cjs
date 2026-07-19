#!/usr/bin/env node
/* perf-guard — headless-free regression gate (Node only, NO browser, NO WebGL).
 * Locks the structural performance wins in index.html so a later edit that removes
 * them fails CI. A rendered draw-call/triangle gate is intentionally NOT run here:
 * CI GL is SwiftShader (software) and rendering the campus would time out. The
 * ≤350 draw / ≤2.0 M triangle worst-view budget is verified by the owner in a real
 * browser via window.__kommilo3d.sceneDraw() + the ?debug=perf overlay (see PERF.md).
 *
 * Usage: node scripts/perf-guard.cjs [path/to/index.html]
 */
const fs = require('fs');
const HTML = process.argv[2] || require('path').join(__dirname, '..', 'index.html');
const src = fs.readFileSync(HTML, 'utf8');

// [label, RegExp | substring, mustExist(default true)]
const checks = [
  ['DPR hard clamp = 1.25',            /maxPixelRatio:\s*1\.25/],
  ['DPR applied via min(devicePixelRatio,...)', /Math\.min\(\s*devicePixelRatio/],
  ['Post chain gated on tier.post',    /quality\[qualityTier\]\.post\s*\)\s*\{\s*composer\.render\(\)/],
  ['Per-tier post flag: High = true',  /high:[^\n]*post:\s*true/],
  ['On-demand: renderNeeded flag',     /let\s+renderNeeded\s*=/],
  ['On-demand: invalidate()',          /function\s+invalidate\s*\(/],
  ["On-demand: controls 'change' hook",/addEventListener\(\s*'change'\s*,\s*invalidate\s*\)/],
  ['On-demand: idle skip returns',     /on-demand IDLE/],
  ['Shadows: autoUpdate = false',      /shadowMap\.autoUpdate\s*=\s*false/],
  ['Shadows: single directional caster (sun)', /sun\.castShadow\s*=\s*true/],
  ['Camera ground clamp y>=0.6',       /camera\.position\.y\s*<\s*0\.6/],
  ['Camera maxPolarAngle = 1.54',      /maxPolarAngle\s*=\s*1\.54/],
  ['Interaction boost present',        /function\s+applyBoost/],
  ['?debug=perf overlay present',      /DEBUG_PERF\s*=\s*location\.search/],
];

// Preservation-Law symbols (must all be present)
const symbols = ['SUPA','signInWithOtp','verifyOtp','KOMMILO_PAY','payFlow','buyPack',
  'claimCredits','PRICING.CREDIT_PACKS','creditShop','modCheck','modStrike',
  'https://kommilo.app/','DEFAULT_DB','wlt_db_v1'];

let ok = true;
console.log('--- perf-guard: structural wins ---');
for (const [label, pat] of checks) {
  const found = pat instanceof RegExp ? pat.test(src) : src.includes(pat);
  if (!found) ok = false;
  console.log((found ? 'PASS ' : 'FAIL ') + label);
}
console.log('--- perf-guard: preservation-law symbols ---');
for (const s of symbols) {
  const found = src.includes(s);
  if (!found) ok = false;
  console.log((found ? 'PASS ' : 'FAIL ') + s);
}
console.log('-----------------------------------');
console.log(ok ? 'perf-guard: ALL PASS' : 'perf-guard: FAILURES ABOVE');
process.exit(ok ? 0 : 1);
