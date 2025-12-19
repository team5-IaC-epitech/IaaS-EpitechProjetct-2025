package middleware

import (
	"crypto/rand"
	"encoding/hex"

	"github.com/gin-gonic/gin"
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
		c.Next()
	}
}

func newCorrelationID() string {
	b := make([]byte, 16)
	_, _ = rand.Read(b)
	return hex.EncodeToString(b)
}
