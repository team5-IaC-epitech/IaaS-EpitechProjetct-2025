package model

import "time"

type Task struct {
	ID                   string    `json:"id"`
	Title                string    `json:"title"`
	Content              string    `json:"content"`
	DueDate              string    `json:"due_date"` // keep as YYYY-MM-DD for API simplicity
	Done                 bool      `json:"done"`
	LastRequestTimestamp time.Time `json:"last_request_timestamp"`
	CreatedAt            time.Time `json:"created_at"`
	UpdatedAt            time.Time `json:"updated_at"`
}

type CreateTaskRequest struct {
	Title            string `json:"title" binding:"required"`
	Content          string `json:"content" binding:"required"`
	DueDate          string `json:"due_date" binding:"required"`          // YYYY-MM-DD
	RequestTimestamp string `json:"request_timestamp" binding:"required"` // RFC3339
}

type UpdateTaskRequest struct {
	Title            *string `json:"title,omitempty"`
	Content          *string `json:"content,omitempty"`
	DueDate          *string `json:"due_date,omitempty"` // YYYY-MM-DD
	Done             *bool   `json:"done,omitempty"`
	RequestTimestamp string  `json:"request_timestamp" binding:"required"` // RFC3339
}

type DeleteTaskRequest struct {
	RequestTimestamp string `json:"request_timestamp" binding:"required"` // RFC3339
}
