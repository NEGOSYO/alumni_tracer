# Alumni Tracer (Flutter) + `alumni_php` (XAMPP)

This Flutter app is designed to use your existing PHP backend located in XAMPP:
`C:\\xampp\\htdocs\\alumni_php\\`

## Backend URL (important)
All API calls are built via `lib/services/api_service.dart`.

Default behavior:
- Web / Windows / macOS: `http://localhost/alumni_php`
- Android emulator: `http://10.0.2.2/alumni_php`

Override the base URL at runtime (recommended for physical devices):

```bash
flutter run --dart-define=API_BASE_URL=http://<your-pc-ip>/alumni_php
```

Example (replace with your PC IP on the same Wi-Fi):

```bash
flutter run --dart-define=API_BASE_URL=http://192.168.1.10/alumni_php
```

## Expected PHP endpoints
Your `alumni_php` folder should contain the endpoints used by the app (examples):
- `login.php`
- `register.php`
- `get_announcements.php`
- `get_jobs.php` (`get_job.php` may remain as a compatibility alias)

Start XAMPP (Apache + MySQL), then run the Flutter app.
