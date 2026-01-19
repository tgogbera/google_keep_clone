package handlers

import (
	"crypto/rand"
	"crypto/sha256"
	"encoding/base64"
	"encoding/hex"
	"net/http"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/golang-jwt/jwt/v5"
	"github.com/sirupsen/logrus"
	"github.com/tgogbera/google_keep_clone-backend/internal/config"
	"github.com/tgogbera/google_keep_clone-backend/internal/database"
	"github.com/tgogbera/google_keep_clone-backend/internal/logger"
	"github.com/tgogbera/google_keep_clone-backend/internal/models"
	"golang.org/x/crypto/bcrypt"
)

// Claims contains the JWT payload for access tokens.
type Claims struct {
	UserID int64  `json:"user_id"`
	Email  string `json:"email"`
	jwt.RegisteredClaims
}

func Register(c *gin.Context) {
	log := logger.WithFields(logrus.Fields{
		"handler": "Register",
		"ip":      c.ClientIP(),
	})

	var req models.RegisterRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		log.WithError(err).Warn("Invalid registration request")
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	log = log.WithField("email", req.Email)
	log.Info("Processing registration request")

	// Check if user already exists
	var existing models.User
	if err := database.DB.Where("email = ?", req.Email).First(&existing).Error; err == nil {
		log.Warn("Registration failed: email already exists")
		c.JSON(http.StatusConflict, gin.H{"error": "User with this email already exists"})
		return
	}

	// Hash password
	hashedPassword, err := bcrypt.GenerateFromPassword([]byte(req.Password), bcrypt.DefaultCost)
	if err != nil {
		log.WithError(err).Error("Failed to hash password")
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to hash password"})
		return
	}

	// Insert user
	user := models.User{
		Email:        req.Email,
		PasswordHash: string(hashedPassword),
	}
	if err := database.DB.Create(&user).Error; err != nil {
		log.WithError(err).Error("Failed to create user in database")
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to create user"})
		return
	}

	log = log.WithField("user_id", user.ID)

	// Create tokens
	accessToken, err := generateAccessToken(user.ID, user.Email)
	if err != nil {
		log.WithError(err).Error("Failed to generate access token")
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to generate access token"})
		return
	}

	refreshToken, err := generateAndStoreRefreshToken(user.ID)
	if err != nil {
		log.WithError(err).Error("Failed to generate refresh token")
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to generate refresh token"})
		return
	}

	// Set refresh token as secure httpOnly cookie
	cfg := config.Get()
	maxAge := int(cfg.RefreshTokenTTL.Seconds())
	secure := cfg.Environment == config.EnvProduction
	c.SetCookie(cfg.RefreshTokenCookieName, refreshToken, maxAge, "/", "", secure, true)

	log.Info("User registered successfully")

	c.JSON(http.StatusCreated, models.AuthResponse{
		Token:        accessToken,
		RefreshToken: refreshToken, // also return in body for convenience (frontend should prefer cookie)
		User:         user.ToDTO(),
	})
}

func Login(c *gin.Context) {
	log := logger.WithFields(logrus.Fields{
		"handler": "Login",
		"ip":      c.ClientIP(),
	})

	var req models.LoginRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		log.WithError(err).Warn("Invalid login request")
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	log = log.WithField("email", req.Email)
	log.Info("Processing login request")

	// Get user from database
	var user models.User
	if err := database.DB.Where("email = ?", req.Email).First(&user).Error; err != nil {
		log.Warn("Login failed: user not found")
		c.JSON(http.StatusUnauthorized, gin.H{"error": "Invalid email or password"})
		return
	}

	// Check password
	err := bcrypt.CompareHashAndPassword([]byte(user.PasswordHash), []byte(req.Password))
	if err != nil {
		log.Warn("Login failed: invalid password")
		c.JSON(http.StatusUnauthorized, gin.H{"error": "Invalid email or password"})
		return
	}

	log = log.WithField("user_id", user.ID)

	// Create tokens
	accessToken, err := generateAccessToken(user.ID, user.Email)
	if err != nil {
		log.WithError(err).Error("Failed to generate access token")
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to generate access token"})
		return
	}

	refreshToken, err := generateAndStoreRefreshToken(user.ID)
	if err != nil {
		log.WithError(err).Error("Failed to generate refresh token")
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to generate refresh token"})
		return
	}

	// Set refresh token as secure httpOnly cookie
	cfg := config.Get()
	maxAge := int(cfg.RefreshTokenTTL.Seconds())
	secure := cfg.Environment == config.EnvProduction
	c.SetCookie(cfg.RefreshTokenCookieName, refreshToken, maxAge, "/", "", secure, true)

	log.Info("User logged in successfully")

	c.JSON(http.StatusOK, models.AuthResponse{
		Token:        accessToken,
		RefreshToken: refreshToken, // included for convenience
		User:         user.ToDTO(),
	})
}

// Refresh exchanges a valid refresh token for a new access token and rotates the refresh token.
func Refresh(c *gin.Context) {
	log := logger.WithFields(logrus.Fields{
		"handler": "Refresh",
		"ip":      c.ClientIP(),
	})

	cfg := config.Get()
	// Prefer cookie
	rt, err := c.Cookie(cfg.RefreshTokenCookieName)
	if err != nil || rt == "" {
		// fallback to JSON body
		var body struct {
			RefreshToken string `json:"refresh_token"`
		}
		if err := c.ShouldBindJSON(&body); err != nil || body.RefreshToken == "" {
			log.Warn("Refresh failed: no refresh token provided")
			c.JSON(http.StatusUnauthorized, gin.H{"error": "refresh token required"})
			return
		}
		rt = body.RefreshToken
	}

	hash := hashToken(rt)
	var stored models.RefreshToken
	if err := database.DB.Where("token_hash = ?", hash).First(&stored).Error; err != nil {
		log.Warn("Refresh failed: invalid refresh token")
		c.JSON(http.StatusUnauthorized, gin.H{"error": "invalid refresh token"})
		return
	}

	log = log.WithField("user_id", stored.UserID)

	if stored.Revoked || stored.ExpiresAt.Before(time.Now()) {
		log.Warn("Refresh failed: token expired or revoked")
		c.JSON(http.StatusUnauthorized, gin.H{"error": "refresh token expired or revoked"})
		return
	}

	// Load user
	var user models.User
	if err := database.DB.First(&user, stored.UserID).Error; err != nil {
		log.WithError(err).Error("Refresh failed: user not found")
		c.JSON(http.StatusInternalServerError, gin.H{"error": "user not found"})
		return
	}

	// Revoke old refresh token (rotation)
	stored.Revoked = true
	if err := database.DB.Save(&stored).Error; err != nil {
		log.WithError(err).Warn("Failed to revoke old refresh token")
	}

	// Create new refresh token
	newRT, err := generateAndStoreRefreshToken(user.ID)
	if err != nil {
		log.WithError(err).Error("Failed to generate new refresh token")
		c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to generate new refresh token"})
		return
	}

	// Set cookie
	maxAge := int(cfg.RefreshTokenTTL.Seconds())
	secure := cfg.Environment == config.EnvProduction
	c.SetCookie(cfg.RefreshTokenCookieName, newRT, maxAge, "/", "", secure, true)

	// Create new access token
	accessToken, err := generateAccessToken(user.ID, user.Email)
	if err != nil {
		log.WithError(err).Error("Failed to generate access token")
		c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to generate access token"})
		return
	}

	log.Info("Token refreshed successfully")

	c.JSON(http.StatusOK, gin.H{
		"token":         accessToken,
		"refresh_token": newRT,
	})
}

// Logout revokes the refresh token (if present) and clears the cookie.
func Logout(c *gin.Context) {
	log := logger.WithFields(logrus.Fields{
		"handler": "Logout",
		"ip":      c.ClientIP(),
	})

	// Try to get user_id from context if available (from AuthMiddleware)
	if userID, exists := c.Get("user_id"); exists {
		log = log.WithField("user_id", userID)
	}

	cfg := config.Get()
	rt, err := c.Cookie(cfg.RefreshTokenCookieName)
	if err == nil && rt != "" {
		hash := hashToken(rt)
		var stored models.RefreshToken
		if err := database.DB.Where("token_hash = ?", hash).First(&stored).Error; err == nil {
			stored.Revoked = true
			if err := database.DB.Save(&stored).Error; err != nil {
				log.WithError(err).Warn("Failed to revoke refresh token during logout")
			} else {
				log.Debug("Refresh token revoked")
			}
		}
	}

	// Clear cookie
	c.SetCookie(cfg.RefreshTokenCookieName, "", -1, "/", "", cfg.Environment == config.EnvProduction, true)

	log.Info("User logged out successfully")

	c.JSON(http.StatusOK, gin.H{"message": "logged out"})
}

func generateAccessToken(userID int64, email string) (string, error) {
	cfg := config.Get()
	expirationTime := time.Now().Add(cfg.AccessTokenTTL)
	claims := &Claims{
		UserID: userID,
		Email:  email,
		RegisteredClaims: jwt.RegisteredClaims{
			ExpiresAt: jwt.NewNumericDate(expirationTime),
			IssuedAt:  jwt.NewNumericDate(time.Now()),
		},
	}

	token := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)
	return token.SignedString([]byte(cfg.JWTSecret))
}

// generateAndStoreRefreshToken creates a random refresh token, stores its hash and returns the raw token.
func generateAndStoreRefreshToken(userID int64) (string, error) {
	// generate 64 random bytes
	raw := make([]byte, 64)
	if _, err := rand.Read(raw); err != nil {
		return "", err
	}
	// base64 encode to make it URL-safe
	token := base64.RawURLEncoding.EncodeToString(raw)
	hash := hashToken(token)

	cfg := config.Get()
	rt := models.RefreshToken{
		TokenHash: hash,
		UserID:    userID,
		ExpiresAt: time.Now().Add(cfg.RefreshTokenTTL),
	}

	if err := database.DB.Create(&rt).Error; err != nil {
		return "", err
	}

	return token, nil
}

func hashToken(t string) string {
	h := sha256.Sum256([]byte(t))
	return hex.EncodeToString(h[:])
}

func AuthMiddleware() gin.HandlerFunc {
	return func(c *gin.Context) {
		log := logger.WithFields(logrus.Fields{
			"middleware": "AuthMiddleware",
			"path":       c.Request.URL.Path,
			"ip":         c.ClientIP(),
		})

		cfg := config.Get()
		tokenString := c.GetHeader("Authorization")
		if tokenString == "" {
			log.Warn("Authorization header missing")
			c.JSON(http.StatusUnauthorized, gin.H{"error": "Authorization header required"})
			c.Abort()
			return
		}

		// Remove "Bearer " prefix if present
		if len(tokenString) > 7 && tokenString[:7] == "Bearer " {
			tokenString = tokenString[7:]
		}

		claims := &Claims{}
		token, err := jwt.ParseWithClaims(tokenString, claims, func(token *jwt.Token) (interface{}, error) {
			return []byte(cfg.JWTSecret), nil
		})

		if err != nil || !token.Valid {
			log.WithError(err).Warn("Invalid token")
			c.JSON(http.StatusUnauthorized, gin.H{"error": "Invalid token"})
			c.Abort()
			return
		}

		log.WithFields(logrus.Fields{
			"user_id": claims.UserID,
			"email":   claims.Email,
		}).Debug("Token validated successfully")

		c.Set("user_id", claims.UserID)
		c.Set("email", claims.Email)
		c.Next()
	}
}
