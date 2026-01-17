package main

import (
	"net/http"

	"github.com/gin-gonic/gin"
	"github.com/tgogbera/google_keep_clone-backend/internal/config"
	"github.com/tgogbera/google_keep_clone-backend/internal/database"
	"github.com/tgogbera/google_keep_clone-backend/internal/handlers"
	"github.com/tgogbera/google_keep_clone-backend/internal/logger"
	"github.com/tgogbera/google_keep_clone-backend/internal/models"
)

func main() {
	// Load configuration (based on environment variables)
	config.Load()
	cfg := config.Get()

	// Initialize logger
	logger.Init(logger.Config{
		Level:       logger.LogLevel(cfg.LogLevel),
		Environment: string(cfg.Environment),
	})

	// Log any config warnings that were collected before logger was available
	for _, warning := range cfg.Warnings {
		logger.Warn(warning)
	}

	// Set Gin mode based on environment
	if cfg.Environment == config.EnvProduction {
		gin.SetMode(gin.ReleaseMode)
	}

	// Initialize database
	if err := database.InitDB(); err != nil {
		logger.WithError(err).Fatal("Failed to initialize database")
	}

	// Create router without default middleware (we'll add our own)
	router := gin.New()

	// Add recovery middleware (handles panics)
	router.Use(logger.RecoveryLogger())

	// Add request logging middleware
	router.Use(logger.RequestLogger())

	// CORS middleware
	router.Use(func(c *gin.Context) {
		c.Writer.Header().Set("Access-Control-Allow-Origin", "*")
		c.Writer.Header().Set("Access-Control-Allow-Credentials", "true")
		c.Writer.Header().Set("Access-Control-Allow-Headers", "Content-Type, Content-Length, Accept-Encoding, X-CSRF-Token, Authorization, accept, origin, Cache-Control, X-Requested-With")
		c.Writer.Header().Set("Access-Control-Allow-Methods", "POST, OPTIONS, GET, PUT, DELETE")

		if c.Request.Method == "OPTIONS" {
			c.AbortWithStatus(204)
			return
		}

		c.Next()
	})

	// Health check
	router.GET("/ping", func(c *gin.Context) {
		c.JSON(200, gin.H{
			"message": "pong",
		})
	})

	// Auth routes
	api := router.Group("/api")
	{
		api.POST("/register", handlers.Register)
		api.POST("/login", handlers.Login)
		api.POST("/refresh", handlers.Refresh)
		api.POST("/logout", handlers.Logout)
	}

	// Protected routes example
	protected := api.Group("/")
	protected.Use(handlers.AuthMiddleware())
	{

		protected.GET("/me", func(c *gin.Context) {
			// Safely extract user_id from context
			userID, exists := c.Get("user_id")
			if !exists {
				c.JSON(http.StatusUnauthorized, gin.H{"error": "user_id not found in context"})
				return
			}

			// Type assert to int64 (claims.UserID is int64)
			userIDInt64, ok := userID.(int64)
			if !ok {
				c.JSON(http.StatusInternalServerError, gin.H{"error": "invalid user_id type"})
				return
			}

			// Validate user_id is positive
			if userIDInt64 <= 0 {
				c.JSON(http.StatusUnauthorized, gin.H{"error": "invalid user_id"})
				return
			}

			// Load full user from database
			var user models.User
			if err := database.DB.First(&user, userIDInt64).Error; err != nil {
				if err.Error() == "record not found" {
					c.JSON(http.StatusNotFound, gin.H{"error": "user not found"})
					return
				}
				c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to fetch user"})
				return
			}

			c.JSON(http.StatusOK, user.ToDTO())
		})

		// Note routes
		protected.POST("/notes", handlers.CreateNote)
		protected.GET("/notes", handlers.GetAllNotes)
		protected.PUT("/notes/:id", handlers.UpdateNote)
		protected.DELETE("/notes/:id", handlers.DeleteNote)
	}

	// Start server with configured port
	addr := ":" + cfg.Port
	logger.WithField("address", addr).Info("Starting server")
	if err := router.Run(addr); err != nil {
		logger.WithError(err).Fatal("Failed to start server")
	}
}
