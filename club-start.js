// A failed dependency must show a message instead of leaving a dead login form.
try { await import('./club.js?v=auth-forms-1'); }
catch { document.getElementById('status').textContent='Account access could not load. Refresh this page and try again. If this continues, the website update may be incomplete.'; }
