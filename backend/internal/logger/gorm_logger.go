package logger

import (
	"context"
	"errors"
	"time"

	"github.com/sirupsen/logrus"
	"gorm.io/gorm"
	gormlogger "gorm.io/gorm/logger"
)

// GormLoggerAdapter adapts logrus to GORM's logger interface
type GormLoggerAdapter struct {
	SlowThreshold         time.Duration
	SourceField           string
	SkipErrRecordNotFound bool
	LogLevel              gormlogger.LogLevel
}

// NewGormLoggerAdapter creates a new GORM logger adapter
// By default, only logs errors and slow queries (>200ms) to reduce noise
func NewGormLoggerAdapter(level LogLevel) *GormLoggerAdapter {
	// GORM logger level controls what gets logged:
	// - Silent: nothing
	// - Error: only errors
	// - Warn: errors + slow queries
	// - Info: errors + slow queries + all queries
	// We default to Warn to only show errors and slow queries
	var gormLevel gormlogger.LogLevel
	switch level {
	case LevelDebug:
		gormLevel = gormlogger.Warn // Even in debug, don't log every query
	case LevelInfo:
		gormLevel = gormlogger.Warn
	case LevelWarn:
		gormLevel = gormlogger.Warn
	case LevelError:
		gormLevel = gormlogger.Error
	default:
		gormLevel = gormlogger.Warn
	}

	return &GormLoggerAdapter{
		SlowThreshold:         200 * time.Millisecond,
		SourceField:           "source",
		SkipErrRecordNotFound: true,
		LogLevel:              gormLevel,
	}
}

// LogMode implements gorm logger.Interface
func (l *GormLoggerAdapter) LogMode(level gormlogger.LogLevel) gormlogger.Interface {
	newLogger := *l
	newLogger.LogLevel = level
	return &newLogger
}

// Info implements gorm logger.Interface
func (l *GormLoggerAdapter) Info(ctx context.Context, msg string, data ...interface{}) {
	if l.LogLevel >= gormlogger.Info {
		Log.WithFields(logrus.Fields{
			"component": "gorm",
		}).Infof(msg, data...)
	}
}

// Warn implements gorm logger.Interface
func (l *GormLoggerAdapter) Warn(ctx context.Context, msg string, data ...interface{}) {
	if l.LogLevel >= gormlogger.Warn {
		Log.WithFields(logrus.Fields{
			"component": "gorm",
		}).Warnf(msg, data...)
	}
}

// Error implements gorm logger.Interface
func (l *GormLoggerAdapter) Error(ctx context.Context, msg string, data ...interface{}) {
	if l.LogLevel >= gormlogger.Error {
		Log.WithFields(logrus.Fields{
			"component": "gorm",
		}).Errorf(msg, data...)
	}
}

// Trace implements gorm logger.Interface
func (l *GormLoggerAdapter) Trace(ctx context.Context, begin time.Time, fc func() (sql string, rowsAffected int64), err error) {
	if l.LogLevel <= gormlogger.Silent {
		return
	}

	elapsed := time.Since(begin)
	sql, rows := fc()

	fields := logrus.Fields{
		"component":     "gorm",
		"elapsed_ms":    elapsed.Milliseconds(),
		"rows_affected": rows,
	}

	// Only log SQL in debug mode to avoid leaking sensitive data
	if l.LogLevel >= gormlogger.Info {
		fields["sql"] = sql
	}

	switch {
	case err != nil && (!errors.Is(err, gorm.ErrRecordNotFound) || !l.SkipErrRecordNotFound):
		fields["error"] = err.Error()
		Log.WithFields(fields).Error("Database query failed")
	case elapsed > l.SlowThreshold && l.SlowThreshold != 0:
		Log.WithFields(fields).Warn("Slow database query")
	case l.LogLevel >= gormlogger.Info:
		Log.WithFields(fields).Debug("Database query executed")
	}
}
