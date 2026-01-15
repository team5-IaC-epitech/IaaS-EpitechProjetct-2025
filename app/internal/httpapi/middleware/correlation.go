package middleware

import (
	"crypto/rand"
	"encoding/hex"
	"time"

	"github.com/gin-gonic/gin"
	"team5/task-manager/internal/logger"
)

const correlationHeader = "correlation_id"

func CorrelationID() gin.HandlerFunc {
	return func(c *gin.Context) {
		cid := c.GetHeader(correlationHeader)
		if cid == "" {
			cid = newCorrelationID()
		}
		c.Set(correlationHeader, cid)
		c.Writer.Header().Set(correlationHeader, cid)

		// Create logger with correlation_id for this request
		log := logger.WithCorrelationID(cid)
		c.Set("logger", log)

		// Log request start
		start := time.Now()
		log.Info("request started",
			"method", c.Request.Method,
			"path", c.Request.URL.Path,
			"remote_addr", c.ClientIP(),
		)

		c.Next()

		// Log request completion
		duration := time.Since(start)
		log.Info("request completed",
			"method", c.Request.Method,
			"path", c.Request.URL.Path,
			"status", c.Writer.Status(),
			"duration_ms", duration.Milliseconds(),
		)
	}
}

func newCorrelationID() string {
	b := make([]byte, 16)
	_, _ = rand.Read(b)
	return hex.EncodeToString(b)
}
