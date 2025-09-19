// sw.js — ضع هذا الملف في نفس المجلد الجذر (/) بجانب index.html
const CACHE_NAME = 'neom-pwa-v1';
const ASSETS = [
  '/', '/index.html', '/styles.css', '/app.css', '/app.js', '/manifest.json',
  '/courses.html', '/about.html', '/contact.html', '/offline-fallback',
  '/icons/icon-192.png', '/icons/icon-512.png'
];

// install -> cache core
self.addEventListener('install', event => {
  event.waitUntil(
    caches.open(CACHE_NAME).then(cache => {
      // keep minimal list; if files missing it's okay (we'll handle)
      return cache.addAll(ASSETS.map(p => new Request(p, {cache: 'reload'}))).catch(()=>console.warn('Some assets failed to cache'));
    })
  );
  self.skipWaiting();
});

// activate -> cleanup
self.addEventListener('activate', event => {
  event.waitUntil(
    caches.keys().then(keys => Promise.all(keys.filter(k => k !== CACHE_NAME).map(k=>caches.delete(k))))
  );
  self.clients.claim();
});

// fetch -> navigation network-first, static cache-first fallback to offline generated HTML
self.addEventListener('fetch', event => {
  const req = event.request;

  // handle navigation: try network then cache then offline fallback
  if (req.mode === 'navigate') {
    event.respondWith(
      fetch(req).then(res => {
        const copy = res.clone();
        caches.open(CACHE_NAME).then(cache => cache.put(req, copy));
        return res;
      }).catch(() => caches.match(req).then(r => r || caches.match('/index.html')).then(r => r || offlineResponse()))
    );
    return;
  }

  // other requests: try cache first, then network
  event.respondWith(
    caches.match(req).then(cached => cached || fetch(req).then(res => {
      const copy = res.clone();
      caches.open(CACHE_NAME).then(cache => cache.put(req, copy));
      return res;
    })).catch(() => {
      // if image requested, return a tiny placeholder (data URI) or cached icon
      if (req.destination === 'image') {
        // data URI of small placeholder (same base64 used in page)
        const data = 'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAACAAAAAgCAYAAABzenr0AAABYElEQVRYR+2XsQ2CMBCGfQPoBjANqQ1kg7iA1CE7kAtogroSdxAVogtUo2jJD3eTQKdxOejZPuxdrFJ1y7IgAdgBKgBbwBuQAH4BjQC94tXv7N9l6I6t5o4A2c9S8Sgv5xDnBNjgD+BRXswAyTYJmkhScJf04o2YUdDPJCsT7sGMBFYygrSNYUkXmCIkT7jMUKsvbS+FRCLGUbxtTH5qbhU93oJKGMrn8Xcd46CcexNiBfZ1BynAjJLBxGlLFGSmnsjIr7SmrMZJ2yFkpYsa8iTkI4fCzVv0AMsdE+GnOJ8n/3jZbwZG1EzXMWZxZ3gUudyywMWFVG0OSBajQlX+z3fQrm7mJuxcPwI8AyUKqH4tMfETAAAAAElFTkSuQmCC';
        return fetch(data);
      }
    })
  );
});

// offlineResponse() -> generate a simple offline HTML response (so no offline.html file needed)
function offlineResponse(){
  const html = `<!doctype html><html lang="ar" dir="rtl"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>غير متصل</title><style>body{background:#08090a;color:#e6eef3;font-family:Arial, Helvetica, sans-serif;display:flex;align-items:center;justify-content:center;height:100vh;margin:0}a{color:#1fb6ff}</style></head><body><div style="text-align:center;padding:20px"><h1>أنت غير متصل</h1><p style="color:#9aa6ae">بعض المحتويات قد تكون متاحة أوفلاين. تأكد من اتصالك أو أعد المحاولة لاحقاً.</p><p><a href="/">العودة للرئيسية</a></p></div></body></html>`;
  return new Response(html, {headers:{'Content-Type':'text/html'}});
}