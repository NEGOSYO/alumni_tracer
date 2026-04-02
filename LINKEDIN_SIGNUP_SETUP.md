# LinkedIn Sign-Up Setup

This app is already prepared on the Flutter side for a LinkedIn-assisted alumni registration flow.

## User Flow

1. User opens the login page.
2. User sees: `New Alumni User? Sign up with LinkedIn or Register here`
3. User clicks `Continue with LinkedIn`
4. Backend starts LinkedIn OAuth
5. Backend receives the LinkedIn callback
6. Backend extracts profile claims
7. Backend checks whether the LinkedIn account is already linked to an existing user
8. If not linked yet, backend redirects back to the Flutter web app with registration-prefill query params
9. Flutter opens the registration screen with LinkedIn name prefilled and read-only
10. User fills the remaining fields and submits the normal registration form

## Current LinkedIn Account Rules

- A LinkedIn account can only be linked to one alumni account
- If the LinkedIn-linked account is already approved, `Continue with LinkedIn` logs the user in automatically
- If the LinkedIn-linked account is still pending, the user is sent back to login with a clear pending-approval message
- If the email already exists in a non-LinkedIn account, the user is told to log in normally or ask the admin to link the account

## Required LinkedIn App Setup

1. Create or configure your LinkedIn developer app
2. Enable `Sign in with LinkedIn using OpenID Connect`
3. Add the backend callback URL to the LinkedIn app

Example callback URL:

```text
http://localhost/alumni_php/linkedin_callback.php
```

For deployment, replace `localhost` with your real server domain.

## Backend Files To Add

Use the real backend files in:

- `C:\xampp\htdocs\alumni_php\linkedin_oauth.php`
- `C:\xampp\htdocs\alumni_php\linkedin_start.php`
- `C:\xampp\htdocs\alumni_php\linkedin_callback.php`

Recommended structure:

- `linkedin_oauth.php`
  - shared LinkedIn config
  - app redirect helpers
  - token exchange helper
  - userinfo fetch helper
- `linkedin_start.php`
  - thin entry file that starts OAuth
- `linkedin_callback.php`
  - thin entry file that handles the callback

## Flutter Contract Expected From Backend

After successful LinkedIn authentication, redirect back to your Flutter app root with query params like:

```text
http://localhost:63582/?auth_flow=linkedin_register&provider=linkedin&li_name=Jenn+Makiling&li_first_name=Jenn&li_last_name=Makiling&li_email=jenn@example.com
```

Supported query keys:

- `auth_flow=linkedin_register`
- `provider=linkedin`
- `li_name`
- `li_first_name`
- `li_last_name`
- `li_email`

## Safe Account Rule Recommended

For this system, the safer initial rule is:

- Do not auto-log the user in from LinkedIn
- Do not automatically link to an existing account
- Only use LinkedIn to prefill registration data
- Let normal registration and admin approval continue as usual

If the imported email already exists:

- let `register.php` reject registration with a clear message
- ask the user to log in normally or contact admin

## Notes

- LinkedIn may not always return email
- Name is enough to prefill the registration form
- Password is still collected by your own system unless you later decide to support full LinkedIn login

## What To Do Next

1. Use the LinkedIn PHP backend files already placed in `C:\xampp\htdocs\alumni_php`.
2. Edit `C:\xampp\htdocs\alumni_php\linkedin_oauth.php` and set:
   - `LINKEDIN_CLIENT_ID`
   - `LINKEDIN_CLIENT_SECRET`
   - `LINKEDIN_REDIRECT_URI`
   - `APP_DEFAULT_REDIRECT`
3. Make sure `LINKEDIN_REDIRECT_URI` exactly matches the redirect URL saved in your LinkedIn app.
4. Start your PHP server and Flutter web app.
5. Open `http://localhost/alumni_php/linkedin_start.php` in the browser and confirm it redirects to LinkedIn.
6. Complete LinkedIn sign-in and confirm the app returns to the register page with LinkedIn name prefilled.
