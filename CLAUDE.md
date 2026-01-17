# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a Google Keep clone built as a full-stack application with a Go backend and Flutter frontend. The backend uses Gin for HTTP routing, GORM for database operations with PostgreSQL, and implements JWT-based authentication with refresh token rotation. The frontend uses Flutter with BLoC (Cubit) for state management, go_router for navigation, and Dio for HTTP requests.

## Development Commands

### Backend (Go)

```bash
# Navigate to backend directory
cd backend

# Install dependencies
go mod download

# Run the backend server
go run cmd/main.go

# Run with Docker Compose (includes PostgreSQL)
docker-compose -f docker-compose.dev.yml up

# Build the backend
go build -o bin/server cmd/main.go

# Run tests (if tests exist)
go test ./...

# Run tests for a specific package
go test ./internal/handlers

# Run tests with verbose output
go test -v ./...
```

### Frontend (Flutter)

```bash
# Navigate to frontend directory
cd frontend

# Install dependencies
flutter pub get

# Run the app (default device)
flutter run

# Run on specific device
flutter run -d <device-id>

# Build for release
flutter build apk        # Android
flutter build ios        # iOS
flutter build web        # Web

# Run tests
flutter test

# Run tests with coverage
flutter test --coverage

# Analyze code
flutter analyze

# Format code
dart format .
```

## Architecture

### Backend Structure

The backend follows a layered architecture:

- **cmd/main.go**: Application entry point, sets up Gin router and middleware
- **internal/config**: Configuration management (environment variables, JWT settings, token TTLs, log level)
- **internal/database**: Database initialization and GORM setup with structured logging
- **internal/logger**: Structured logging with Logrus (request logging, GORM adapter, panic recovery)
- **internal/models**: Data models (User, Note, RefreshToken)
- **internal/handlers**: HTTP handlers for auth and notes endpoints with structured logging

**Key implementation details:**
- Uses int64 for user IDs and note IDs across all models and handlers
- Database auto-migration runs on startup for User, Note, and RefreshToken models
- CORS middleware is configured to allow all origins (suitable for development)

### Frontend Structure

The frontend follows clean architecture principles:

- **lib/core**: Core utilities and configurations
  - **config**: API base URL configuration (ApiConfig)
  - **network**: HTTP client (ApiClient), interceptors (AuthInterceptor for automatic token refresh), custom exceptions
  - **storage**: Secure token storage (TokenStorage using flutter_secure_storage)
  - **router**: GoRouter configuration with auth-based redirects
  - **observers**: BLoC observer for debugging
- **lib/data**: Data layer
  - **models**: Data models (User, Note, AuthResponse)
  - **repositories**: Repository implementations (AuthRepository, NoteRepository)
- **lib/presentation**: Presentation layer
  - **cubit**: State management with Cubit (AuthCubit, NoteCubit)
  - **screens**: UI screens organized by feature (login, register, home)

**State management flow:**
1. BLoC providers are initialized in main.dart using MultiRepositoryProvider
2. AuthCubit is provided at the root level and checks auth status on app start
3. GoRouter uses AuthCubit state for navigation redirects
4. AuthInterceptor automatically refreshes tokens on 401 responses

### Authentication Flow

The app implements a robust token-based authentication system:

**Backend:**
- Access tokens: Short-lived JWTs (default 15 minutes), signed with JWT_SECRET
- Refresh tokens: Long-lived opaque tokens (default 30 days), stored as SHA-256 hash in database
- Refresh token rotation: Old token revoked when /api/refresh is called, new token issued
- HttpOnly cookies: Refresh tokens set as secure, HttpOnly cookies (production-ready)

**Frontend:**
- Access tokens stored in TokenStorage (flutter_secure_storage)
- AuthInterceptor adds Bearer token to all requests
- On 401 response, interceptor automatically calls refresh endpoint and retries the original request
- Refresh tokens may be stored as fallback when cookies aren't available

**Endpoints:**
- POST /api/register - Register new user
- POST /api/login - Login
- POST /api/refresh - Refresh access token (rotates refresh token)
- POST /api/logout - Revoke refresh token and clear cookie
- GET /api/me - Get current user (protected)
- POST /api/notes - Create note (protected)
- GET /api/notes - Get all notes for user (protected)
- PUT /api/notes/:id - Update note (protected)
- DELETE /api/notes/:id - Delete note (protected)

**Auth middleware:**
- Located in backend/internal/handlers/auth.go (AuthMiddleware function)
- Extracts and validates JWT from Authorization header
- Sets user_id (as int64) in Gin context for downstream handlers

### Environment Configuration

**Backend (.env file in backend/):**
```
APP_ENV=development
PORT=8080
JWT_SECRET=<generate-a-random-secret-key>
POSTGRES_USER=<your-db-user>
POSTGRES_PASSWORD=<your-db-password>
POSTGRES_DB=google_keep_clone
DB_HOST=db                    # "localhost" for local dev without Docker
DB_PORT=5432
DB_USER=<your-db-user>
DB_PASSWORD=<your-db-password>
DB_NAME=google_keep_clone
DB_SSLMODE=disable
ACCESS_TOKEN_TTL_MINUTES=15
REFRESH_TOKEN_TTL_DAYS=30
LOG_LEVEL=debug               # debug, info, warn, error (defaults: debug in dev, info in prod)
```

**Note:** Generate JWT_SECRET with `openssl rand -hex 32`. Use same credentials for POSTGRES_* and DB_* variables.

**Frontend (lib/core/config/api_config.dart):**
- Change `baseUrl` based on target platform:
  - iOS Simulator: `http://localhost:8080/api`
  - Android Emulator: `http://10.0.2.2:8080/api`
  - Physical Device: `http://<your-computer-ip>:8080/api`

## Database

PostgreSQL is used for data persistence. The database schema includes:
- users (id, email, password, created_at, updated_at)
- notes (id, title, content, user_id, created_at, updated_at)
- refresh_tokens (id, user_id, token_hash, expires_at, revoked, created_at)

**Local development with Docker:**
```bash
cd backend
docker-compose -f docker-compose.dev.yml up db  # Start only PostgreSQL
```

The database is automatically migrated on backend startup.

## Testing Authentication Manually

See backend/README_AUTH.md for detailed curl examples to test the auth flow.

Quick test:
```bash
# Register
curl -c cookies.txt -X POST http://localhost:8080/api/register \
  -H "Content-Type: application/json" \
  -d '{"email":"test@example.com","password":"password123"}'

# Login
curl -c cookies.txt -X POST http://localhost:8080/api/login \
  -H "Content-Type: application/json" \
  -d '{"email":"test@example.com","password":"password123"}'

# Use access token (replace <token>)
curl -H "Authorization: Bearer <token>" http://localhost:8080/api/me

# Refresh token
curl -b cookies.txt -c cookies.txt -X POST http://localhost:8080/api/refresh

# Logout
curl -b cookies.txt -X POST http://localhost:8080/api/logout
```

## Common Patterns

### Adding a New Protected Endpoint (Backend)

1. Define model/request structs in `internal/models/`
2. Create handler function in `internal/handlers/`
3. Register route in `cmd/main.go` under the `protected` group
4. Handler can access `user_id` from context: `c.Get("user_id")` (returns int64)

### Adding a New Feature (Frontend)

1. Create data model in `lib/data/models/`
2. Add repository methods in `lib/data/repositories/`
3. Create Cubit for state management in `lib/presentation/cubit/`
4. Build UI in `lib/presentation/screens/`
5. Register routes in `lib/core/router/app_router.dart` if needed
6. Provide Cubit in appropriate scope (screen-level BlocProvider or app-level MultiBlocProvider)

### Error Handling

**Backend:** Return appropriate HTTP status codes with JSON error messages:
```go
c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid input"})
```

**Frontend:** ApiClient automatically throws typed exceptions (BadRequestException, UnauthorizedException, etc.). Catch and handle in Cubits:
```dart
try {
  await repository.someMethod();
} on ApiException catch (e) {
  emit(SomeErrorState(e.message));
}
```
