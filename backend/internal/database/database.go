package database

import (
	"fmt"
	"os"

	"github.com/tgogbera/google_keep_clone-backend/internal/config"
	"github.com/tgogbera/google_keep_clone-backend/internal/logger"
	"github.com/tgogbera/google_keep_clone-backend/internal/models"
	"gorm.io/driver/postgres"
	"gorm.io/gorm"
)

// InitDB initializes the global GORM DB connection and runs migrations.
func InitDB() error {
	host := getEnv("DB_HOST", "localhost")
	port := getEnv("DB_PORT", "5432")
	user := getEnv("DB_USER", "postgres")
	password := getEnv("DB_PASSWORD", "postgres")
	dbname := getEnv("DB_NAME", "google_keep_clone")
	sslmode := getEnv("DB_SSLMODE", "disable")

	logger.WithFields(map[string]interface{}{
		"host":    host,
		"port":    port,
		"dbname":  dbname,
		"sslmode": sslmode,
	}).Info("Connecting to database")

	dsn := fmt.Sprintf(
		"host=%s port=%s user=%s password=%s dbname=%s sslmode=%s",
		host, port, user, password, dbname, sslmode,
	)

	// Get log level from config
	cfg := config.Get()
	gormLogger := logger.NewGormLoggerAdapter(logger.LogLevel(cfg.LogLevel))

	var err error
	DB, err = gorm.Open(postgres.Open(dsn), &gorm.Config{
		Logger: gormLogger,
	})
	if err != nil {
		logger.WithError(err).Error("Failed to connect to database")
		return fmt.Errorf("failed to connect to database: %w", err)
	}

	logger.Info("Database connection established")

	// Run migrations (including refresh tokens for session management)
	logger.Info("Running database migrations")
	if err := DB.AutoMigrate(&models.User{}, &models.Note{}, &models.RefreshToken{}); err != nil {
		logger.WithError(err).Error("Failed to run migrations")
		return fmt.Errorf("failed to run migrations: %w", err)
	}

	logger.Info("Database migrations completed successfully")
	return nil
}

func getEnv(key, defaultValue string) string {
	if value := os.Getenv(key); value != "" {
		return value
	}
	return defaultValue
}
