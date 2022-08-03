// Call install event
self.addEventListener('install', (e) => {
    console.log("Service Worker: Installed");
})

// Call activate event
self.addEventListener('activate', (e) => {
    console.log("Service Worker: Activated");
})

// Call fetch event
self.addEventListener('fetch', (e) => {
    if (e.request.url.includes("/standard")) {
        console.log("Service Worker: modify header b/c s3proxy call")
        var req = new Request(e.request.url, {
            method: e.request.method,
            headers: {
                ...e.request.headers
            },
            mode: e.request.mode,
            credentials: e.request.credentials,
            redirect: e.request.redirect
        });
        e.respondWith(fetch(req))
    }
    else {
        console.log("Service Worker: do not modify header b/c other call")
        e.respondWith(fetch(e.request))
    }
});
/**
 * The AWS client automatically generates an Authorization request
 * header. On the AAW environment, we have an EnvoyFilter that seems
 * to automatically reject requests that have authorization headers
 * other than 'cookie' or 'x-auth-token'. To avoid refactoring/forking
 * the code for aws-js-explorer, this service worker acts as a 
 * "middleware" on the client side to modify outgoing requests from
 * the aws-js-explorer application and remove the erroneous Authorization
 * header.
 */
// self.addEventListener('fetch', (e) => {
//     // Requests and headers are immutable, so need to recreate the
//     // request with the Authorization header removed
//     if (e.request.url.)
//     console.log("modifying request")

// })