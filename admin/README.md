# DhanaOS Admin

Next.js admin panel for the DhanaOS jewelry production app (the Flutter app in the parent folder).

**Frontend only.** Data is the app's sample data (`src/data/seed.json`, exported from the Flutter app) kept in a
zustand store and saved in the browser's localStorage, so changes survive a refresh. Settings → *Reset demo data*
restores the samples. Nothing is sent to a server, and changes here do not reach the mobile app yet.

## Run

```sh
npm install
npm run dev      # http://localhost:3000
npm run build && npm start
```

Sign in with the demo admin: `admin@dhanaos.com` / `admin123` (only Admin and Manufacturing Engineer accounts can
sign in). The login is a demo check in the browser, not real authentication.

## Pages

| Route | What it manages |
|---|---|
| `/` | Dashboard: KPIs, stage metrics, priority orders, action queue, activity |
| `/production` | Kanban board by production stage (drag to move jobs) |
| `/jobs`, `/jobs/new`, `/jobs/[id]` | Jobs list, create job, job detail with the 14-stage process, thread and files |
| `/partners` | Designers, casters, retailers, stone providers, labs, couriers |
| `/inventory` | Metal stock (receive/issue) and gemstones (assign to jobs) |
| `/files` | All job files |
| `/users` | App users, roles and the permission matrix |
| `/settings` | Company, appearance, notifications, stages, account, reset demo data |

## Structure

- `src/lib` — types, stages (+ per-stage record logic, same as the app), store, seed loader, formatting
- `src/components/ui.tsx` — design-system components (tokens in `src/app/globals.css`, light "DhanaOS" + dark
  "Industrial Precision")
- `src/components/views` — one view per page; `src/app/(admin)` holds the routes, `src/proxy.ts` guards them
