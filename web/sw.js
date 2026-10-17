// Offline-capable service worker shared by the Nesty / ADP / Wortwerk / Fritz
// web apps. Network-first for the app shell so a deploy is picked up on the
// next load, stale-while-revalidate for everything else so a repeat visit works
// offline. wortwerk-shell-v1 is replaced per app at copy time.
'use strict';

const CACHE = 'wortwerk-shell-v1';
const SHELL = ['./', './index.html', './manifest.json', './flutter_bootstrap.js'];

self.addEventListener('install', (event) => {
  event.waitUntil(
    caches
      .open(CACHE)
      .then((cache) => cache.addAll(SHELL))
      .catch(() => {})
      .then(() => self.skipWaiting()),
  );
});

self.addEventListener('activate', (event) => {
  event.waitUntil(
    caches
      .keys()
      .then((keys) => Promise.all(keys.filter((key) => key !== CACHE).map((key) => caches.delete(key))))
      .then(() => self.clients.claim()),
  );
});

// Entry points must always be fresh, otherwise a new deploy can be masked by an
// old cached bundle. Everything else is served from cache first and refreshed
// in the background.
function isShellRequest(url) {
  const path = url.pathname;
  return (
    path.endsWith('/') ||
    path.endsWith('/index.html') ||
    path.endsWith('/flutter_bootstrap.js') ||
    path.endsWith('/main.dart.js') ||
    path.endsWith('/manifest.json')
  );
}

self.addEventListener('fetch', (event) => {
  const request = event.request;
  if (request.method !== 'GET') return;

  const url = new URL(request.url);
  if (url.origin !== self.location.origin) return;

  if (request.mode === 'navigate' || isShellRequest(url)) {
    event.respondWith(
      fetch(request)
        .then((response) => {
          if (response && response.ok) {
            const copy = response.clone();
            caches.open(CACHE).then((cache) => cache.put(request, copy)).catch(() => {});
          }
          return response;
        })
        .catch(() => caches.match(request).then((cached) => cached || caches.match('./index.html'))),
    );
    return;
  }

  event.respondWith(
    caches.match(request).then((cached) => {
      const network = fetch(request)
        .then((response) => {
          if (response && response.ok) {
            const copy = response.clone();
            caches.open(CACHE).then((cache) => cache.put(request, copy)).catch(() => {});
          }
          return response;
        })
        .catch(() => cached);
      return cached || network;
    }),
  );
});
