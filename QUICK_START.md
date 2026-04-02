# Quick Start - Alumni Tracer

## Backend Location
Your live PHP backend is in:
`C:\xampp\htdocs\alumni_php\`

## Start These First
1. Start XAMPP Apache
2. Start XAMPP MySQL
3. Make sure the database name is `alumni_tracer`

## Landing Page
The landing page now uses:
- `get_announcements.php`
- `get_jobs.php`

The Contact section is manual only.
There is no message submission from the app.

## Main URLs
- `http://localhost/alumni_php/get_announcements.php`
- `http://localhost/alumni_php/get_jobs.php`

## Flutter Base URL
Default:
- Web / Windows / macOS: `http://localhost/alumni_php`
- Android emulator: `http://10.0.2.2/alumni_php`

Physical device example:

```bash
flutter run --dart-define=API_BASE_URL=http://192.168.1.10/alumni_php
```

## Basic Test
1. Open landing page
2. Confirm announcements load
3. Confirm jobs load
4. Open Contact section and confirm manual contact details are visible
5. Click `Apply Now` or `Read More`
6. Confirm login prompt appears

## Tracer Test
1. Log in as alumni
2. Open tracer form
3. Submit with signature
4. Confirm save succeeds
5. Confirm signed record appears in admin/dean tracer pages

## Notes
- `get_jobs.php` is the main jobs endpoint
- `get_job.php` may remain as a compatibility alias
- `submit_contact.php` is not needed by the current landing page
