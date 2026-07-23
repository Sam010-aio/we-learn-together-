/* Kommilo Service Worker — LIGHTNESS RESCUE Ph0
   Delivery-Regeln:
   - HTML: NETWORK-FIRST → ein neuer Build erreicht den Nutzer beim nächsten Reload (Cache nur offline).
   - Cache-Name an den Build gebunden (kommilo-v${BUILD}) → Build-Wechsel invalidiert alten Cache
     deterministisch; `activate` löscht alle Fremd-Caches.
   - skipWaiting + clients.claim → der neue Worker übernimmt sofort; die Seite zeigt den Reload-Hinweis.
   - Vendored three.js (/vendor/) + CORE + CDN-Fallback (Fonts/Foto-Texturen): CACHE-FIRST (immutabel). */
const BUILD = '2026.07.23-380fde8';         // GLEICHE Zeichenkette wie window.__BUILD.id in index.html (Delivery-Stempel)
const CACHE = 'kommilo-v' + BUILD;          // Cache-Name direkt aus dem Build-Stempel abgeleitet → kommilo-v2026.07.23-380fde8
const CORE  = ['./', './index.html', './manifest.webmanifest', './icon-192.png', './icon-512.png',
               './vendor/three/three.module.js']; // App-kritische Boot-Bytes vorab
self.addEventListener('install', e => {
  // Best-effort-Precache: ein einzelnes fehlendes Icon darf die Installation nicht kippen
  e.waitUntil(caches.open(CACHE).then(c => Promise.all(CORE.map(u => c.add(u).catch(() => {})))));
  self.skipWaiting();
});
self.addEventListener('activate', e => {
  e.waitUntil(caches.keys().then(ks => Promise.all(ks.filter(k => k !== CACHE).map(k => caches.delete(k)))));
  self.clients.claim();
});
self.addEventListener('fetch', e => {
  const req = e.request, u = req.url;
  // HTML immer network-first: neuer Build schlägt den Cache
  if (req.mode === 'navigate' || u.endsWith('index.html')) {
    e.respondWith(fetch(req).then(res => { const cp = res.clone(); caches.open(CACHE).then(c => c.put(req, cp)); return res })
      .catch(() => caches.match(req).then(hit => hit || caches.match('./index.html'))));
    return;
  }
  // Vendored Engine (same-origin, immutabel), CORE, CDN-Fallback (Fonts/Foto-Texturen): cache-first
  if (u.includes('/vendor/') || u.includes('cdn.jsdelivr.net') || u.includes('fonts.g') ||
      CORE.some(c => u.endsWith(c.replace('./', '')))) {
    e.respondWith(caches.open(CACHE).then(async c => {
      const hit = await c.match(req); if (hit) return hit;
      const res = await fetch(req); if (res && res.ok) c.put(req, res.clone()); return res;
    }));
  }
});
