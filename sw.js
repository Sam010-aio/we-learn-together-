const CACHE='wlt-v19';
const CORE=['./index.html','./manifest.webmanifest','./icon-192.png','./icon-512.png'];
self.addEventListener('install',e=>{ e.waitUntil(caches.open(CACHE).then(c=>c.addAll(CORE))); self.skipWaiting(); });
self.addEventListener('activate',e=>{ e.waitUntil(caches.keys().then(ks=>Promise.all(ks.filter(k=>k!==CACHE).map(k=>caches.delete(k))))); self.clients.claim(); });
self.addEventListener('fetch',e=>{
  const u=e.request.url;
  if(e.request.mode==='navigate'||u.endsWith('index.html')){
    e.respondWith(fetch(e.request).then(res=>{ caches.open(CACHE).then(c=>c.put(e.request,res.clone())); return res })
      .catch(()=>caches.match(e.request)));
    return;
  }
  if(u.includes('cdn.jsdelivr.net')||u.includes('fonts.g')||CORE.some(c=>u.endsWith(c.replace('./','')))){
    e.respondWith(caches.open(CACHE).then(async c=>{
      const hit=await c.match(e.request); if(hit) return hit;
      const res=await fetch(e.request);
      if(res.ok) c.put(e.request,res.clone());
      return res; }));
  }
});
