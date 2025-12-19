package main

import (
	"fmt"
	"time"

	"github.com/golang-jwt/jwt/v5"
)

func main() {
	secret := []byte("devsecret")
	claims := jwt.MapClaims{"sub": "dev", "exp": time.Now().Add(24 * time.Hour).Unix()}
	t := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)
	s, _ := t.SignedString(secret)
	fmt.Println(s)
}
