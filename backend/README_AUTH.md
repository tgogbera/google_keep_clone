# Authentication (Access + Refresh Tokens)

This document describes how the backend implements token-based authentication and how to test it locally.

## Environment variables

- `JWT_SECRET` - signing key for access tokens (required)
- `ACCESS_TOKEN_TTL_MINUTES` - access token lifetime in minutes (default 15)
- `REFRESH_TOKEN_TTL_DAYS` - refresh token lifetime in days (default 7)
- `REFRESH_TOKEN_COOKIE` - cookie name for refresh token (default `refresh_token`)

## Behavior / Best practices implemented

- Access tokens are short-lived JWTs (signed with `JWT_SECRET`).
- Refresh tokens are long-lived opaque tokens: a cryptographically random token is returned to the client, while only a SHA-256 hash is persisted in the database.
- Refresh tokens are rotated on use: when `/api/refresh` is called the old token is revoked and a new refresh token is issued.
- Refresh tokens are set as HttpOnly cookies (secure in production) to mitigate XSS.

## Endpoints

- `POST /api/register` - registers a new user, returns an access token in JSON and sets a refresh token cookie
- `POST /api/login` - logs in, returns an access token and sets refresh token cookie
- `POST /api/refresh` - exchanges the refresh token (cookie or body) for a new access token and rotates the refresh token
- `POST /api/logout` - revokes the refresh token and clears the cookie

## Quick manual test (curl)

1. Register (saves the refresh cookie in `cookies.txt`):

```bash
curl -v -c cookies.txt -X POST http://localhost:8080/api/register \
  -H "Content-Type: application/json" \
  -d '{"email":"test@example.com","password":"password123"}'
```

1. Login (cookie stored in `cookies.txt`):

```bash
curl -v -c cookies.txt -X POST http://localhost:8080/api/login \
  -H "Content-Type: application/json" \
  -d '{"email":"test@example.com","password":"password123"}'
```

1. Use access token to call protected endpoint:

```bash
# Replace <token> with the `token` field from login response
curl -H "Authorization: Bearer <token>" http://localhost:8080/api/me
```

1. Refresh the access token (cookie `cookies.txt` used):

```bash
curl -v -b cookies.txt -c cookies.txt -X POST http://localhost:8080/api/refresh
```

1. Logout (revokes refresh token and clears cookie):

```bash
curl -v -b cookies.txt -c cookies.txt -X POST http://localhost:8080/api/logout
```

## DB inspection

The `refresh_tokens` table stores only a hashed token; to inspect active tokens (for debugging):

```bash
SELECT id, user_id, expires_at, revoked, created_at FROM refresh_tokens ORDER BY created_at DESC;
```

---

If you want, I can also update the frontend to stop relying on the `token` field and instead read the access token from the responses consistently (or rely on cookie-only refresh flows).
