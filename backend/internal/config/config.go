package config

import (
	"log"
	"os"
	"strconv"
	"time"
)

type Environment string

const (
	EnvDevelopment Environment = "development"
	EnvProduction  Environment = "production"
)

// Config holds all runtime configuration for the app.
type Config struct {
	// Environment indicates whether the app is running in development or production.
	Environment Environment

	// Server
	Port string

	// Database
	DatabaseURL string

	// Auth / Security
	JWTSecret string

	// Token TTLs
	AccessTokenTTL  time.Duration // e.g., 15m
	RefreshTokenTTL time.Duration // e.g., 7d

	// Refresh token cookie
	RefreshTokenCookieName string
}

var cfg *Config

// Load initializes the global configuration from environment variables.
// It should be called once on application startup.
func Load() {
	if cfg != nil {
		// Already loaded
		return
	}

	env := getEnv("APP_ENV", "development")
	var environment Environment
	switch Environment(env) {
	case EnvProduction:
		environment = EnvProduction
	default:
		environment = EnvDevelopment
	}

	port := getEnv("PORT", "8080")

	dbURL := os.Getenv("DATABASE_URL")
	if dbURL == "" {
		log.Println("WARNING: DATABASE_URL is not set")
	}

	jwtSecret := os.Getenv("JWT_SECRET")
	if jwtSecret == "" {
		log.Println("WARNING: JWT_SECRET is not set")
	}

	// TTLs: read minutes/days from env with sensible defaults
	atMin := getEnvInt("ACCESS_TOKEN_TTL_MINUTES", 15)
	rtDays := getEnvInt("REFRESH_TOKEN_TTL_DAYS", 7)

	cfg = &Config{
		Environment:            environment,
		Port:                   port,
		DatabaseURL:            dbURL,
		JWTSecret:              jwtSecret,
		AccessTokenTTL:         time.Duration(atMin) * time.Minute,
		RefreshTokenTTL:        time.Duration(rtDays) * 24 * time.Hour,
		RefreshTokenCookieName: getEnv("REFRESH_TOKEN_COOKIE", "refresh_token"),
	}
}

// Get returns the loaded configuration. It panics if Load has not been called.
func Get() *Config {
	if cfg == nil {
		log.Fatal("config not loaded: call config.Load() at startup")
	}
	return cfg
}

func getEnv(key, fallback string) string {
	if val := os.Getenv(key); val != "" {
		return val
	}
	return fallback
}

func getEnvInt(key string, fallback int) int {
	valStr := os.Getenv(key)
	if valStr == "" {
		return fallback
	}
	v, err := strconv.Atoi(valStr)
	if err != nil {
		log.Printf("WARNING: invalid int for %s: %v, using fallback %d", key, err, fallback)
		return fallback
	}
	return v
}
