package service

import (
	"fmt"
	"time"
)

func ParseRFC3339(s string) (time.Time, error) {
	t, err := time.Parse(time.RFC3339, s)
	if err != nil {
		return time.Time{}, fmt.Errorf("invalid request_timestamp (RFC3339 required)")
	}
	return t, nil
}

func ParseDateYYYYMMDD(s string) (time.Time, error) {
	t, err := time.Parse("2006-01-02", s)
	if err != nil {
		return time.Time{}, fmt.Errorf("invalid due_date (YYYY-MM-DD required)")
	}
	return t, nil
}
