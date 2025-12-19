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
FROM gcr.io/distroless/base-debian12

WORKDIR /app

# binary + migrations (required by golang-migrate file://db/migrations)
COPY --from=build /app/api /app/api

# non-root
USER nonroot:nonroot

EXPOSE 8080
ENTRYPOINT ["/app/api"]