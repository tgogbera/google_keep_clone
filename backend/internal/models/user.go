package models

import "time"

type User struct {
	ID           uint      `json:"id" gorm:"primaryKey"`
	Email        string    `json:"email" gorm:"uniqueIndex;size:255;not null"`
	PasswordHash string    `json:"-" gorm:"size:255;not null"`
	CreatedAt    time.Time `json:"created_at"`
	UpdatedAt    time.Time `json:"updated_at"`
}

type RegisterRequest struct {
	Email    string `json:"email" binding:"required,email"`
	Password string `json:"password" binding:"required,min=6"`
}

type LoginRequest struct {
	Email    string `json:"email" binding:"required,email"`
	Password string `json:"password" binding:"required"`
}

// UserDTO represents a user data transfer object without sensitive information
type UserDTO struct {
	ID        uint      `json:"id"`
	Email     string    `json:"email"`
	CreatedAt time.Time `json:"created_at"`
	UpdatedAt time.Time `json:"updated_at"`
}

// ToDTO converts a User model to UserDTO
func (u *User) ToDTO() UserDTO {
	return UserDTO{
		ID:        u.ID,
		Email:     u.Email,
		CreatedAt: u.CreatedAt,
		UpdatedAt: u.UpdatedAt,
	}
}

type AuthResponse struct {
	// Token is the access token (kept for backward compatibility).
	Token        string  `json:"token"`
	RefreshToken string  `json:"refresh_token,omitempty"`
	User         UserDTO `json:"user"`
}
