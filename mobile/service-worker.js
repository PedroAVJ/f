const cacheName = 'dot-__BUILD_ID__';
const files = __STATIC_FILES__;

self.addEventListener('install', event => {
  event.waitUntil(caches.open(cacheName).then(cache => cache.addAll(files)).then(() => self.skipWaiting()));
});
self.addEventListener('activate', event => {
  event.waitUntil(caches.keys().then(keys => Promise.all(keys.filter(key => key.startsWith('dot-') && key !== cacheName).map(key => caches.delete(key)))).then(() => self.clients.claim()));
});
self.addEventListener('fetch', event => {
  const url = new URL(event.request.url);
  if (event.request.method !== 'GET' || url.origin !== self.location.origin || url.pathname.startsWith('/api/') || url.pathname === '/health') return;
  event.respondWith(fetch(event.request).then(response => {
    if (response.ok && files.includes(url.pathname)) {
      const copy = response.clone();
      event.waitUntil(caches.open(cacheName).then(cache => cache.put(event.request, copy)));
    }
    return response;
  }).catch(async () => {
    const cached = await caches.match(event.request);
    return cached ?? new Response('Dot sin conexión', { status: 503, headers: { 'Content-Type': 'text/plain; charset=utf-8' } });
  }));
});
