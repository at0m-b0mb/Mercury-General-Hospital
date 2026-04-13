// Mercury General Hospital — Patient Portal v2.3
// Frontend initialisation

// TODO (IT-2247): Move role authorisation fully server-side.
// Currently the portal reads the HTTP cookie 'role' on both the
// client (for UI rendering) and server (camera.php, dashboard).
// This was a temporary workaround for the multi-tenancy testing
// environment and MUST be removed before the portal goes to
// production.  Any client can forge Cookie: role=admin to
// unlock restricted sections.

document.addEventListener('DOMContentLoaded', function () {
    // Highlight the active nav link
    var links = document.querySelectorAll('header nav a');
    links.forEach(function (link) {
        if (window.location.pathname !== '/' &&
            link.getAttribute('href') === window.location.pathname) {
            link.classList.add('active');
        }
    });

    // Show current role indicator in header if available
    var roleCookie = document.cookie.split(';')
        .map(function (c) { return c.trim(); })
        .filter(function (c) { return c.startsWith('role='); });
    if (roleCookie.length) {
        var roleVal = roleCookie[0].split('=')[1];
        var tag = document.createElement('span');
        tag.className = 'role-indicator';
        tag.textContent = '👤 ' + roleVal;
        var nav = document.querySelector('header nav');
        if (nav) { nav.appendChild(tag); }
    }
});
