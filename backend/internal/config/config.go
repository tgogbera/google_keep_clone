package config

import (
	"log"
	"os"
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

	cfg = &Config{
		Environment: environment,
		Port:        port,
		DatabaseURL: dbURL,
		JWTSecret:   jwtSecret,
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
