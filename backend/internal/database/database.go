package database

import (
	"fmt"
	"os"

	"github.com/tgogbera/google_keep_clone-backend/internal/models"
	"gorm.io/driver/postgres"
	"gorm.io/gorm"
	"gorm.io/gorm/logger"
)

// InitDB initializes the global GORM DB connection and runs migrations.
func InitDB() error {
	host := getEnv("DB_HOST", "localhost")
	port := getEnv("DB_PORT", "5432")
	user := getEnv("DB_USER", "postgres")
	password := getEnv("DB_PASSWORD", "postgres")
	dbname := getEnv("DB_NAME", "google_keep_clone")
	sslmode := getEnv("DB_SSLMODE", "disable")

	dsn := fmt.Sprintf(
		"host=%s port=%s user=%s password=%s dbname=%s sslmode=%s",
		host, port, user, password, dbname, sslmode,
	)

	var err error
	DB, err = gorm.Open(postgres.Open(dsn), &gorm.Config{
		Logger: logger.Default.LogMode(logger.Info),
	})
	if err != nil {
		return fmt.Errorf("failed to connect to database: %w", err)
	}

	// Run migrations (including refresh tokens for session management)
	if err := DB.AutoMigrate(&models.User{}, &models.Note{}, &models.RefreshToken{}); err != nil {
		return fmt.Errorf("failed to run migrations: %w", err)
	}

	return nil
}

func getEnv(key, defaultValue string) string {
	if value := os.Getenv(key); value != "" {
		return value
	}
	return defaultValue
}
