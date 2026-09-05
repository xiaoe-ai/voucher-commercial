const CACHE_NAME = 'commercial-voucher-app-shell-v4';

const STATIC_ASSETS = [
  './offline.html',
  './admin-icon-180.png',
  './admin-icon-192.png',
  './admin-icon-512.png',
  './partner-icon-180.png',
  './partner-icon-192.png',
  './partner-icon-512.png',
  './staff-icon-180.png',
  './staff-icon-192.png',
  './staff-icon-512.png',
  './commercial-brand.js',
  './company-setup.html',
  './voucher.html'
];

self.addEventListener('install', event => {
  event.waitUntil(caches.open(CACHE_NAME).then(cache => cache.addAll(STATIC_ASSETS)));
  self.skipWaiting();
});

self.addEventListener('activate', event => {
  event.waitUntil(caches.keys().then(keys => Promise.all(keys.filter(k => k !== CACHE_NAME).map(k => caches.delete(k)))));
  self.clients.claim();
});

self.addEventListener('fetch', event => {
  const request = event.request;
  if (request.method !== 'GET') return;
  const url = new URL(request.url);
  if (url.hostname.includes('supabase.co') || url.pathname.includes('/auth/') || url.pathname.includes('/rest/') || url.pathname.includes('/rpc/')) return;
  if (request.mode === 'navigate') {
    event.respondWith(fetch(request).catch(() => caches.match('./offline.html')));
    return;
  }
  if (url.origin === self.location.origin) {
    event.respondWith(caches.match(request).then(cached => cached || fetch(request).then(response => {
      const copy = response.clone();
      caches.open(CACHE_NAME).then(cache => cache.put(request, copy));
      return response;
    })));
  }
});
