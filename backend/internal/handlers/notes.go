package handlers

import (
	"net/http"
	"strconv"

	"github.com/gin-gonic/gin"
	"github.com/sirupsen/logrus"
	"github.com/tgogbera/google_keep_clone-backend/internal/database"
	"github.com/tgogbera/google_keep_clone-backend/internal/logger"
	"github.com/tgogbera/google_keep_clone-backend/internal/models"
)

func CreateNote(c *gin.Context) {
	log := logger.WithFields(logrus.Fields{
		"handler": "CreateNote",
		"ip":      c.ClientIP(),
	})

	var req models.CreateNoteRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		log.WithError(err).Warn("Invalid create note request")
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	// Get user ID from context (set by AuthMiddleware)
	userID, exists := c.Get("user_id")
	if !exists {
		log.Warn("User not authenticated")
		c.JSON(http.StatusUnauthorized, gin.H{"error": "User not authenticated"})
		return
	}

	log = log.WithField("user_id", userID)

	// Create note
	note := models.Note{
		Title:   req.Title,
		Content: req.Content,
		UserID:  userID.(int64),
	}

	if err := database.DB.Create(&note).Error; err != nil {
		log.WithError(err).Error("Failed to create note")
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to create note"})
		return
	}

	log.WithField("note_id", note.ID).Info("Note created successfully")

	c.JSON(http.StatusCreated, note)
}

func GetAllNotes(c *gin.Context) {
	log := logger.WithFields(logrus.Fields{
		"handler": "GetAllNotes",
		"ip":      c.ClientIP(),
	})

	// Get user ID from context (set by AuthMiddleware)
	userID, exists := c.Get("user_id")
	if !exists {
		log.Warn("User not authenticated")
		c.JSON(http.StatusUnauthorized, gin.H{"error": "User not authenticated"})
		return
	}

	log = log.WithField("user_id", userID)

	var notes []models.Note
	if err := database.DB.Where("user_id = ?", userID.(int64)).Order("created_at DESC").Find(&notes).Error; err != nil {
		log.WithError(err).Error("Failed to retrieve notes")
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to retrieve notes"})
		return
	}

	log.WithField("count", len(notes)).Debug("Notes retrieved successfully")

	c.JSON(http.StatusOK, notes)
}

func UpdateNote(c *gin.Context) {
	log := logger.WithFields(logrus.Fields{
		"handler": "UpdateNote",
		"ip":      c.ClientIP(),
	})

	// Get note ID from URL parameter
	noteIDStr := c.Param("id")
	noteID, err := strconv.ParseInt(noteIDStr, 10, 64)
	if err != nil {
		log.WithField("note_id_str", noteIDStr).Warn("Invalid note ID format")
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid note ID"})
		return
	}

	log = log.WithField("note_id", noteID)

	// Get user ID from context (set by AuthMiddleware)
	userID, exists := c.Get("user_id")
	if !exists {
		log.Warn("User not authenticated")
		c.JSON(http.StatusUnauthorized, gin.H{"error": "User not authenticated"})
		return
	}

	log = log.WithField("user_id", userID)

	// Check if note exists and belongs to user
	var note models.Note
	if err := database.DB.Where("id = ? AND user_id = ?", noteID, userID.(int64)).First(&note).Error; err != nil {
		log.Warn("Note not found or does not belong to user")
		c.JSON(http.StatusNotFound, gin.H{"error": "Note not found"})
		return
	}

	// Read raw JSON to check which fields are provided
	var jsonData map[string]interface{}
	if err := c.ShouldBindJSON(&jsonData); err != nil {
		log.WithError(err).Warn("Invalid update request body")
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	// Build updates map - only include fields that are present in JSON
	updates := make(map[string]interface{})
	if title, exists := jsonData["title"]; exists {
		updates["title"] = title
	}
	if content, exists := jsonData["content"]; exists {
		updates["content"] = content
	}

	// Check if at least one field is being updated
	if len(updates) == 0 {
		log.Warn("No fields provided for update")
		c.JSON(http.StatusBadRequest, gin.H{"error": "At least one field (title or content) must be provided"})
		return
	}

	// Apply updates
	if err := database.DB.Model(&note).Updates(updates).Error; err != nil {
		log.WithError(err).Error("Failed to update note")
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to update note"})
		return
	}

	// Reload note to get updated values
	database.DB.First(&note, note.ID)

	log.Info("Note updated successfully")

	c.JSON(http.StatusOK, note)
}

func DeleteNote(c *gin.Context) {
	log := logger.WithFields(logrus.Fields{
		"handler": "DeleteNote",
		"ip":      c.ClientIP(),
	})

	// Get note ID from URL parameter
	noteIDStr := c.Param("id")
	noteID, err := strconv.ParseInt(noteIDStr, 10, 64)
	if err != nil {
		log.WithField("note_id_str", noteIDStr).Warn("Invalid note ID format")
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid note ID"})
		return
	}

	log = log.WithField("note_id", noteID)

	// Get user ID from context (set by AuthMiddleware)
	userID, exists := c.Get("user_id")
	if !exists {
		log.Warn("User not authenticated")
		c.JSON(http.StatusUnauthorized, gin.H{"error": "User not authenticated"})
		return
	}

	log = log.WithField("user_id", userID)

	// Check if note exists and belongs to user
	var note models.Note
	if err := database.DB.Where("id = ? AND user_id = ?", noteID, userID.(int64)).First(&note).Error; err != nil {
		log.Warn("Note not found or does not belong to user")
		c.JSON(http.StatusNotFound, gin.H{"error": "Note not found"})
		return
	}

	// Delete note
	if err := database.DB.Delete(&note).Error; err != nil {
		log.WithError(err).Error("Failed to delete note")
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to delete note"})
		return
	}

	log.Info("Note deleted successfully")

	c.JSON(http.StatusOK, gin.H{"message": "Note deleted successfully"})
}
