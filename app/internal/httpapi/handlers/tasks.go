package handlers

import (
	"errors"
	"net/http"
	"time"

	"github.com/gin-gonic/gin"

	"team5/task-manager/internal/model"
	"team5/task-manager/internal/service"
	"team5/task-manager/internal/store/postgres"
)

type TasksHandler struct {
	store *postgres.TasksStore
}

func NewTasksHandler(store *postgres.TasksStore) *TasksHandler {
	return &TasksHandler{store: store}
}

func (h *TasksHandler) Create(c *gin.Context) {
	var req model.CreateTaskRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.Status(http.StatusBadRequest)
		return
	}

	reqTS, err := service.ParseRFC3339(req.RequestTimestamp)
	if err != nil {
		c.Status(http.StatusBadRequest)
		return
	}

	due, err := service.ParseDateYYYYMMDD(req.DueDate)
	if err != nil {
		c.Status(http.StatusBadRequest)
		return
	}

	// Timeout court pour détecter surcharge → 429 (pragmatique)
	ctx, cancel := contextWithTimeout(c, 800*time.Millisecond)
	defer cancel()

	t, err := h.store.Create(ctx, req.Title, req.Content, due, reqTS)
	if err != nil {
		if isOverload(err) {
			c.Status(http.StatusTooManyRequests)
			return
		}
		c.Status(http.StatusInternalServerError)
		return
	}
	c.JSON(http.StatusCreated, t)
}

func (h *TasksHandler) List(c *gin.Context) {
	ctx, cancel := contextWithTimeout(c, 800*time.Millisecond)
	defer cancel()

	tasks, err := h.store.List(ctx)
	if err != nil {
		if isOverload(err) {
			c.Status(http.StatusTooManyRequests)
			return
		}
		c.Status(http.StatusInternalServerError)
		return
	}
	c.JSON(http.StatusOK, tasks)
}

func (h *TasksHandler) Get(c *gin.Context) {
	id := c.Param("id")
	ctx, cancel := contextWithTimeout(c, 800*time.Millisecond)
	defer cancel()

	t, err := h.store.Get(ctx, id)
	if err != nil {
		if errors.Is(err, postgres.ErrNotFound) {
			c.Status(http.StatusNotFound)
			return
		}
		if isOverload(err) {
			c.Status(http.StatusTooManyRequests)
			return
		}
		c.Status(http.StatusInternalServerError)
		return
	}
	c.JSON(http.StatusOK, t)
}

func (h *TasksHandler) Update(c *gin.Context) {
	id := c.Param("id")
	var req model.UpdateTaskRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.Status(http.StatusBadRequest)
		return
	}

	reqTS, err := service.ParseRFC3339(req.RequestTimestamp)
	if err != nil {
		c.Status(http.StatusBadRequest)
		return
	}

	var due *time.Time
	if req.DueDate != nil {
		d, err := service.ParseDateYYYYMMDD(*req.DueDate)
		if err != nil {
			c.Status(http.StatusBadRequest)
			return
		}
		due = &d
	}

	ctx, cancel := contextWithTimeout(c, 800*time.Millisecond)
	defer cancel()

	t, err := h.store.Update(ctx, id, req, due, reqTS)
	if err != nil {
		if errors.Is(err, postgres.ErrNotFound) {
			c.Status(http.StatusNotFound)
			return
		}
		if errors.Is(err, postgres.ErrConflict) {
			c.Status(http.StatusConflict)
			return
		}
		if isOverload(err) {
			c.Status(http.StatusTooManyRequests)
			return
		}
		c.Status(http.StatusInternalServerError)
		return
	}
	c.JSON(http.StatusOK, t)
}

func (h *TasksHandler) Delete(c *gin.Context) {
	id := c.Param("id")
	var req model.DeleteTaskRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.Status(http.StatusBadRequest)
		return
	}

	reqTS, err := service.ParseRFC3339(req.RequestTimestamp)
	if err != nil {
		c.Status(http.StatusBadRequest)
		return
	}

	ctx, cancel := contextWithTimeout(c, 800*time.Millisecond)
	defer cancel()

	err = h.store.Delete(ctx, id, reqTS)
	if err != nil {
		if errors.Is(err, postgres.ErrNotFound) {
			c.Status(http.StatusNotFound)
			return
		}
		if errors.Is(err, postgres.ErrConflict) {
			c.Status(http.StatusConflict)
			return
		}
		if isOverload(err) {
			c.Status(http.StatusTooManyRequests)
			return
		}
		c.Status(http.StatusInternalServerError)
		return
	}
	c.Status(http.StatusOK)
}
