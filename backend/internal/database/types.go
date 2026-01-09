package database

import "gorm.io/gorm"

// DB is the global GORM database handle used across the application.
var DB *gorm.DB
