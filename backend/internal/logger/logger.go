package logger

import (
	"io"
	"os"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/sirupsen/logrus"
)

// Log is the global logger instance
var Log *logrus.Logger

// LogLevel represents the logging level
type LogLevel string

const (
	LevelDebug LogLevel = "debug"
	LevelInfo  LogLevel = "info"
	LevelWarn  LogLevel = "warn"
	LevelError LogLevel = "error"
)

// Config holds logger configuration
type Config struct {
	Level       LogLevel
	Environment string // "development" or "production"
}

// Init initializes the global logger with the given configuration
func Init(cfg Config) {
	Log = logrus.New()
	Log.SetOutput(os.Stdout)

	// Set log level
	switch cfg.Level {
	case LevelDebug:
		Log.SetLevel(logrus.DebugLevel)
	case LevelWarn:
		Log.SetLevel(logrus.WarnLevel)
	case LevelError:
		Log.SetLevel(logrus.ErrorLevel)
	default:
		Log.SetLevel(logrus.InfoLevel)
	}

	// Use JSON formatter in production, text formatter in development
	if cfg.Environment == "production" {
		Log.SetFormatter(&logrus.JSONFormatter{
			TimestampFormat: time.RFC3339,
		})
	} else {
		Log.SetFormatter(&logrus.TextFormatter{
			FullTimestamp:   true,
			TimestampFormat: "2006-01-02 15:04:05",
			DisableColors:   true, // Disable colors for better compatibility
		})
	}

	Log.Info("Logger initialized",
		" level=", cfg.Level,
		" environment=", cfg.Environment,
	)
}

// WithField creates a new entry with a single field
func WithField(key string, value interface{}) *logrus.Entry {
	return Log.WithField(key, value)
}

// WithFields creates a new entry with multiple fields
func WithFields(fields logrus.Fields) *logrus.Entry {
	return Log.WithFields(fields)
}

// WithError creates a new entry with an error field
func WithError(err error) *logrus.Entry {
	return Log.WithError(err)
}

// Debug logs a debug message
func Debug(args ...interface{}) {
	Log.Debug(args...)
}

// Info logs an info message
func Info(args ...interface{}) {
	Log.Info(args...)
}

// Warn logs a warning message
func Warn(args ...interface{}) {
	Log.Warn(args...)
}

// Error logs an error message
func Error(args ...interface{}) {
	Log.Error(args...)
}

// Fatal logs a fatal message and exits
func Fatal(args ...interface{}) {
	Log.Fatal(args...)
}

// Debugf logs a formatted debug message
func Debugf(format string, args ...interface{}) {
	Log.Debugf(format, args...)
}

// Infof logs a formatted info message
func Infof(format string, args ...interface{}) {
	Log.Infof(format, args...)
}

// Warnf logs a formatted warning message
func Warnf(format string, args ...interface{}) {
	Log.Warnf(format, args...)
}

// Errorf logs a formatted error message
func Errorf(format string, args ...interface{}) {
	Log.Errorf(format, args...)
}

// Fatalf logs a formatted fatal message and exits
func Fatalf(format string, args ...interface{}) {
	Log.Fatalf(format, args...)
}

// RequestLogger returns a Gin middleware that logs HTTP requests
func RequestLogger() gin.HandlerFunc {
	return func(c *gin.Context) {
		// Start timer
		start := time.Now()
		path := c.Request.URL.Path
		query := c.Request.URL.RawQuery

		// Process request
		c.Next()

		// Calculate latency
		latency := time.Since(start)

		// Get status code
		statusCode := c.Writer.Status()

		// Get client IP
		clientIP := c.ClientIP()

		// Get user ID if available (set by AuthMiddleware)
		var userID interface{} = "anonymous"
		if id, exists := c.Get("user_id"); exists {
			userID = id
		}

		// Build log fields
		fields := logrus.Fields{
			"status":     statusCode,
			"method":     c.Request.Method,
			"path":       path,
			"query":      query,
			"ip":         clientIP,
			"user_agent": c.Request.UserAgent(),
			"latency":    latency.String(),
			"latency_ms": latency.Milliseconds(),
			"user_id":    userID,
		}

		// Add error if present
		if len(c.Errors) > 0 {
			fields["errors"] = c.Errors.String()
		}

		// Log based on status code
		entry := Log.WithFields(fields)
		switch {
		case statusCode >= 500:
			entry.Error("Server error")
		case statusCode >= 400:
			entry.Warn("Client error")
		case statusCode >= 300:
			entry.Info("Redirection")
		default:
			entry.Info("Request completed")
		}
	}
}

// RecoveryLogger returns a Gin middleware that recovers from panics and logs them
func RecoveryLogger() gin.HandlerFunc {
	return func(c *gin.Context) {
		defer func() {
			if err := recover(); err != nil {
				Log.WithFields(logrus.Fields{
					"error":  err,
					"path":   c.Request.URL.Path,
					"method": c.Request.Method,
					"ip":     c.ClientIP(),
				}).Error("Panic recovered")

				c.AbortWithStatus(500)
			}
		}()
		c.Next()
	}
}

// GormLogger implements gorm logger.Interface for structured logging
type GormLogger struct {
	SlowThreshold time.Duration
	LogLevel      LogLevel
}

// NewGormLogger creates a new GORM logger
func NewGormLogger(level LogLevel) *GormLogger {
	return &GormLogger{
		SlowThreshold: 200 * time.Millisecond,
		LogLevel:      level,
	}
}

// Writer returns an io.Writer that writes to the logger
func Writer() io.Writer {
	return Log.Writer()
}
