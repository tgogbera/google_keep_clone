package models

import "time"

// RefreshToken stores a hashed refresh token for a user session.
// We store only a hash so raw tokens can't be recovered from the DB.
type RefreshToken struct {
	ID        int64     `json:"id" gorm:"primaryKey"`
	TokenHash string    `json:"-" gorm:"size:255;not null;index"`
	UserID    int64     `json:"user_id" gorm:"index;not null"`
	ExpiresAt time.Time `json:"expires_at"`
	Revoked   bool      `json:"revoked" gorm:"default:false"`
	CreatedAt time.Time `json:"created_at"`
}
