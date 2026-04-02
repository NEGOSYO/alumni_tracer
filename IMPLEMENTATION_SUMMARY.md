# Alumni Tracer - Implementation Summary

## Landing Page
The landing page currently does these things:
- loads announcements from `get_announcements.php`
- loads jobs from `get_jobs.php`
- shows a manual contact directory
- blocks full details unless the user logs in

## Contact Flow
The old contact form submission flow has been removed from the Flutter app.

What changed:
- removed the contact form submit behavior from `landing_page.dart`
- removed dependency on `submit_contact.php` from the landing page
- replaced the form with manual contact details

## Active Backend Direction
Use the real backend in:
`C:\xampp\htdocs\alumni_php\`

Important active endpoints for the app include:
- `login.php`
- `register.php`
- `get_announcements.php`
- `get_jobs.php`
- `submit_tracer.php`
- `check_tracer.php`
- `get_tracer_submissions.php`
- `get_reports.php`
- `log_activity.php`

## Tracer Flow
The tracer flow stores:
- live tracer data in `tracer_responses`
- signed tracer archive records in `signed_tracer_submissions`
- activity events in `activity_logs`

## Current Status
- landing page jobs and announcements are connected
- manual contact details are shown instead of message submission
- signed tracer flow is connected
- activity logging is connected
