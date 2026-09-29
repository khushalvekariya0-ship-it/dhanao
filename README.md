# DhanaOS

Flutter (Android) frontend for DhanaOS — a jewelry production workflow app, built from the two Google Stitch exports
(`stitch_jewelry_production_workflow` and `stitch_remix_of_jewelry_production_workflow`).

Frontend only: all data is in-memory sample data (`lib/core/mock_data.dart`) and resets when the app restarts.

## Structure

- `lib/core/` — theme (light "DhanaOS" + dark "Industrial Precision"), models, app state, routes, formatting, asset paths
- `lib/widgets/` — shared UI building blocks (cards, chips, choice groups, upload boxes, wizard/detail scaffolds, timelines)
- `lib/screens/` — one file per page:
  - `shell/` bottom nav (Dash / Flow / Stock / Orders), drawer, search
  - `dashboard/`, `production/`, `jobs/`, `inventory/` — main tabs and job detail
  - `stages/` — CAD review, pricing, casting, QC, certification, shipping, workflow tracker, order details
  - `new_job/` — quick capture flow and full job-order wizard
  - `inquiry/`, `more/` — create inquiry, partners, files, settings
- `assets/` — bundled fonts (Hanken Grotesk, JetBrains Mono) and design images

## Build

```sh
flutter pub get
flutter build apk --release                 # universal APK
flutter build apk --release --split-per-abi # smaller per-ABI APKs
```
