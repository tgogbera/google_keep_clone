package config

import (
	"os"
	"strconv"
	"time"
)

type Environment string

const (
	EnvDevelopment Environment = "development"
	EnvProduction  Environment = "production"
)

// LogLevel represents the logging level
type LogLevel string

const (
	LogLevelDebug LogLevel = "debug"
	LogLevelInfo  LogLevel = "info"
	LogLevelWarn  LogLevel = "warn"
	LogLevelError LogLevel = "error"
)

// Config holds all runtime configuration for the app.
type Config struct {
	// Environment indicates whether the app is running in development or production.
	Environment Environment

	// Server
	Port string

	// Auth / Security
	JWTSecret string

	// Token TTLs
	AccessTokenTTL  time.Duration // e.g., 15m
	RefreshTokenTTL time.Duration // e.g., 7d

	// Refresh token cookie
	RefreshTokenCookieName string

	// Logging
	LogLevel LogLevel

	// Warnings collected during config load (before logger is available)
	Warnings []string
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

	var warnings []string

	jwtSecret := os.Getenv("JWT_SECRET")
	if jwtSecret == "" {
		warnings = append(warnings, "JWT_SECRET is not set - using empty secret is insecure")
	}

	// TTLs: read minutes/days from env with sensible defaults
	atMin := getEnvInt("ACCESS_TOKEN_TTL_MINUTES", 15)
	rtDays := getEnvInt("REFRESH_TOKEN_TTL_DAYS", 7)

	// Log level: default to debug in development, info in production
	logLevelStr := getEnv("LOG_LEVEL", "")
	var logLevel LogLevel
	switch LogLevel(logLevelStr) {
	case LogLevelDebug:
		logLevel = LogLevelDebug
	case LogLevelInfo:
		logLevel = LogLevelInfo
	case LogLevelWarn:
		logLevel = LogLevelWarn
	case LogLevelError:
		logLevel = LogLevelError
	default:
		if environment == EnvProduction {
			logLevel = LogLevelInfo
		} else {
			logLevel = LogLevelDebug
		}
	}

	cfg = &Config{
		Environment:            environment,
		Port:                   port,
		JWTSecret:              jwtSecret,
		AccessTokenTTL:         time.Duration(atMin) * time.Minute,
		RefreshTokenTTL:        time.Duration(rtDays) * 24 * time.Hour,
		RefreshTokenCookieName: getEnv("REFRESH_TOKEN_COOKIE", "refresh_token"),
		LogLevel:               logLevel,
		Warnings:               warnings,
	}
}

// Get returns the loaded configuration. It panics if Load has not been called.
func Get() *Config {
	if cfg == nil {
		panic("config not loaded: call config.Load() at startup")
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
		// Invalid int values silently use fallback - this is acceptable for config
		return fallback
	}
	return v
}
