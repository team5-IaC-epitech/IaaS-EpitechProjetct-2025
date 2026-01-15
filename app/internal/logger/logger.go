package logger

import (
	"log/slog"
	"os"
)

var Logger *slog.Logger

func Init() {
	// JSON structured logging for GCP Cloud Logging
	handler := slog.NewJSONHandler(os.Stdout, &slog.HandlerOptions{
		Level: slog.LevelInfo,
	})
	Logger = slog.New(handler)
}

// WithCorrelationID creates a new logger with correlation_id attached
func WithCorrelationID(correlationID string) *slog.Logger {
	return Logger.With("correlation_id", correlationID)
}
