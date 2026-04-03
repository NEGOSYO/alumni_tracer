## Render Proxy Setup

The deployed Flutter web app should call `/api/...` on the same Render domain.
Render must then rewrite those requests to your backend service.

Configure this route in your Render static site:

- Source: `/api/*`
- Destination: `https://your-backend-service.onrender.com/*`
- Action: `Rewrite`

Keep your existing SPA catch-all rule as well:

- Source: `/*`
- Destination: `/index.html`
- Action: `Rewrite`

After saving the route:

1. Trigger a new Render deploy.
2. Open the deployed site.
3. In DevTools Network, confirm requests go to `/api/get_jobs.php` and `/api/login.php`.

This keeps the browser on the same Render origin and helps avoid cross-origin or preflight issues.
