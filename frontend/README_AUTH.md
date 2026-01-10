# Frontend auth notes

The frontend has been updated to work with the backend's access+refresh token flow.

What changed:

- `AuthResponse` now includes an optional `refresh_token` field.
- `TokenStorage` may store a `refresh_token` as a fallback when HttpOnly cookies are not available.
- `AuthRepository` saves `refresh_token` when returned by the server and exposes `refresh()` and `logout()` helpers.
- `AuthInterceptor` now attempts an automatic token refresh when a 401 is encountered and will retry the failed request once.

Notes:

- The backend prefers that refresh tokens be stored as HttpOnly cookies. The frontend only stores the refresh token locally when the server includes it in the response body (this is a fallback, not preferred for security reasons).
- For web clients, ensure cookies are sent by configuring the environment (CORS + credentials) if you want to rely on cookie-only refresh flows.

Testing tips:

- Login/register normally. On success you should see the access token in the response and, if the backend provided it, a refresh token saved in secure storage.
- Trigger an action after access token expiry to confirm the interceptor performs refresh and the original request is retried successfully.
