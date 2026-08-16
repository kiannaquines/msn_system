# M&S Rider

Flutter rider application for assigned deliveries, cash-on-delivery confirmation,
Mapbox route guidance, and permission-aware location sharing with a durable SQLite
retry queue.

## Run

The app expects the shared packages in `ui/packages`. Supply only public runtime
configuration:

```sh
flutter pub get
flutter run \
  --dart-define=API_BASE_URL=https://api.example.com \
  --dart-define=MAPBOX_PUBLIC_TOKEN=your-public-mapbox-token
```

No backend or Supabase secret belongs in this app.

## Native location setup

After generating the Android and iOS runners with the installed Flutter SDK,
configure these platform permissions before producing releases:

- Android: `ACCESS_FINE_LOCATION`, `ACCESS_COARSE_LOCATION`,
  `ACCESS_BACKGROUND_LOCATION`, and `FOREGROUND_SERVICE_LOCATION`; declare the
  geolocator foreground service and explain active tracking in the permission UI.
- iOS: `NSLocationWhenInUseUsageDescription` and
  `NSLocationAlwaysAndWhenInUseUsageDescription`; enable the Xcode **Location
  updates** background mode.

Tracking can begin only after pickup, displays a persistent Android notification
or iOS background indicator, and is stopped on completion, cancellation, or
logout. The server remains authoritative and every queued write carries a stable
idempotency key.
