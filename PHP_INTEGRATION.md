# Alumni Tracer - PHP Integration Guide

## Overview
This Flutter app uses the PHP backend in:
`C:\xampp\htdocs\alumni_php\`

The landing page now:
- fetches announcements
- fetches jobs
- shows manual contact details only
- requires login before viewing full job or announcement details

## Active Landing Page Endpoints
- `GET /get_announcements.php`
- `GET /get_jobs.php`

## Contact Section
The landing page no longer sends contact messages through the system.

Users now contact the alumni office manually using the contact details shown in the app.

Because of that:
- `submit_contact.php` is not required by the Flutter landing page anymore
- `contact_messages` is not required for the current landing page flow

## Authentication Note
`_isUserLoggedIn()` in the landing page still returns `false`, so login is always required before opening full job or announcement details.

## Backend Base URL
- Web / Windows / macOS: `http://localhost/alumni_php`
- Android emulator: `http://10.0.2.2/alumni_php`

Override if needed:

```bash
flutter run --dart-define=API_BASE_URL=http://<your-pc-ip>/alumni_php
```

## Notes
- Keep `get_jobs.php` as the main jobs endpoint
- `get_job.php` may remain only as a compatibility alias
- The tracer flow uses `submit_tracer.php`, `check_tracer.php`, `get_tracer_submissions.php`, and `tracer_signing_support.php`
