# M&S Flutter Web Admin

Responsive operations dashboard for catalog management, order assignment,
riders, live delivery monitoring, COD records, audit history, and reports.

## Run

This app requires Flutter with Dart 3.6 or newer and the shared packages in
`../../packages`.

```sh
flutter create --platforms=web .
flutter pub get
flutter run -d chrome \
  --dart-define=API_BASE_URL=https://your-api.example.com \
  --dart-define=MAPBOX_PUBLIC_TOKEN=your-public-mapbox-token
```

Production mode requires `API_BASE_URL` and uses the shared typed client for
authentication, stores, menu items, orders, assignments, riders, deliveries,
reports, feedback, and audit records. There is no automatic fallback.

For credential-free UI review only, opt into demo mode explicitly:

```sh
flutter run -d chrome --dart-define=DEMO_MODE=true
```

No service-role key or private secret belongs in the web build.

## Verify and deploy

```sh
flutter analyze
flutter test
flutter build web --release \
  --dart-define=API_BASE_URL=https://your-api.example.com \
  --dart-define=MAPBOX_PUBLIC_TOKEN=your-public-mapbox-token
```

Deploy `build/web` as a static Vercel project. Configure the backend CORS allow
list with the resulting production origin. CSV is downloaded in-browser;
“Print / PDF” uses the browser print dialog so operators can save a PDF.
