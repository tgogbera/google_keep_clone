package handlers

import (
	"net/http"

	"github.com/gin-gonic/gin"
	"github.com/tgogbera/google_keep_clone-backend/internal/database"
	"github.com/tgogbera/google_keep_clone-backend/internal/models"
)

func CreateNote(c *gin.Context) {
	var req models.CreateNoteRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	// Get user ID from context (set by AuthMiddleware)
	userID, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "User not authenticated"})
		return
	}

	// Create note
	note := models.Note{
		Title:   req.Title,
		Content: req.Content,
		UserID:  userID.(uint),
	}

	if err := database.DB.Create(&note).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to create note"})
		return
	}

	c.JSON(http.StatusCreated, note)
}
