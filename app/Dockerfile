# ---- build stage ----
FROM golang:1.24-alpine AS build

WORKDIR /app

# deps
COPY go.mod go.sum ./
RUN go mod download

# source
COPY . .

# build
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -trimpath -ldflags="-s -w" -o api ./cmd/api


# ---- runtime stage ----
FROM alpine:3.19

# Install ca-certificates for HTTPS
RUN apk add --no-cache ca-certificates tzdata && \
    addgroup -g 65532 -S nonroot && \
    adduser -u 65532 -S nonroot -G nonroot

WORKDIR /app

# binary + migrations (required by golang-migrate file://db/migrations)
COPY --from=build /app/api /app/api

# non-root
USER nonroot:nonroot

EXPOSE 8080
ENTRYPOINT ["/app/api"]