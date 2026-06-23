/* ═══════════════════════════════════════════════
   Movie Room Remote — Service Worker
   LAZLAB Creations
═══════════════════════════════════════════════ */
const CACHE = 'movie-room-v3';
const ASSETS = [
  './theater-remote.html',
  './manifest.json',
  './icon.svg',
  './icon-192.svg',
];

self.addEventListener('install', e => {
  e.waitUntil(
    caches.open(CACHE).then(c => c.addAll(ASSETS)).then(() => self.skipWaiting())
  );
});

self.addEventListener('activate', e => {
  e.waitUntil(
    caches.keys().then(keys =>
      Promise.all(keys.filter(k => k !== CACHE).map(k => caches.delete(k)))
    ).then(() => self.clients.claim())
  );
});

self.addEventListener('fetch', e => {
  // Network-first for HA API calls — never cache those
  if (e.request.url.includes('/api/') || e.request.url.includes('homeassistant')) {
    return;
  }
  // Cache-first for app shell assets
  e.respondWith(
    caches.match(e.request).then(cached => {
      if (cached) return cached;
      return fetch(e.request).then(resp => {
        if (resp && resp.status === 200 && resp.type === 'basic') {
          const clone = resp.clone();
          caches.open(CACHE).then(c => c.put(e.request, clone));
        }
        return resp;
      });
    })
  );
});
