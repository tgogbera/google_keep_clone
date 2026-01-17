# Google Keep Clone

A full-stack Google Keep clone built with Go (backend) and Flutter (frontend).

## Prerequisites

- Go 1.21+
- Flutter 3.x
- Docker & Docker Compose (for PostgreSQL)

## Quick Start

### 1. Start the database

```bash
cd backend
docker-compose -f docker-compose.dev.yml up db -d
```

### 2. Configure backend environment

```bash
cd backend
cp .env.example .env  # Edit with your settings
```

Required variables in `.env`:
- `JWT_SECRET` - Generate with `openssl rand -hex 32`
- `DB_*` - Database connection settings

### 3. Run the backend

```bash
cd backend
go run cmd/main.go
```

Server starts at `http://localhost:8080`

### 4. Run the frontend

```bash
cd frontend
flutter pub get
flutter run
```

> **Note:** Update `baseUrl` in `lib/core/config/api_config.dart` based on your target:
> - iOS Simulator: `http://localhost:8080/api`
> - Android Emulator: `http://10.0.2.2:8080/api`
> - Physical device: `http://<your-ip>:8080/api`

## Tech Stack

**Backend:** Go, Gin, GORM, PostgreSQL, JWT authentication

**Frontend:** Flutter, BLoC (Cubit), GoRouter, Dio

## Credits

Solution for [Coding Challenge](https://codingchallenges.fyi/challenges/challenge-keep)
