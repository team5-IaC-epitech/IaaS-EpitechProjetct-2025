package handlers

import (
	"context"
	"errors"
	"time"

	"github.com/gin-gonic/gin"
)

func contextWithTimeout(c *gin.Context, d time.Duration) (context.Context, context.CancelFunc) {
	return context.WithTimeout(c.Request.Context(), d)
}

// Overload detection minimaliste (tu peux raffiner ensuite)
func isOverload(err error) bool {
	return errors.Is(err, context.DeadlineExceeded)
}
