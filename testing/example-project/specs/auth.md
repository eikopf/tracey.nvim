# Authentication

## Login

r[auth.login]
Users must be able to log in with a username and password.

r[auth.login.validation]
The system must validate that both username and password are non-empty before attempting authentication.

r[auth.login.rate_limit]
Failed login attempts must be rate-limited to 5 attempts per minute.

## Logout

r[auth.logout]
Users must be able to log out, which invalidates their current session.

## Session

r[auth.session]
Authenticated users receive a session token that expires after 24 hours.

r[auth.session.refresh]
Sessions can be refreshed within 1 hour of expiration.
