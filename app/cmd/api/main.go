package main

import (
	"context"
	"database/sql"
	"fmt"
	"io/fs"
	"log"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/golang-migrate/migrate/v4"
	"github.com/golang-migrate/migrate/v4/database/postgres"
	_ "github.com/golang-migrate/migrate/v4/database/postgres"
	_ "github.com/golang-migrate/migrate/v4/source/file"
	"github.com/golang-migrate/migrate/v4/source/iofs"
	_ "github.com/lib/pq"

	migfs "team5/task-manager/db/migrations"
	"team5/task-manager/internal/config"
	"team5/task-manager/internal/httpapi"
	"team5/task-manager/internal/otel"
)

func main() {
	cfg, err := config.Load()
	if err != nil {
		log.Fatalf("config: %v", err)
	}

	sub, err := fs.Sub(migfs.FS, ".")
	if err != nil {
		log.Fatalf("migrations fs: %v", err)
	}

	src, err := iofs.New(sub, ".")
	if err != nil {
		log.Fatalf("migrations source: %v", err)
	}

	db, err := sql.Open("postgres", cfg.DatabaseURL)
	if err != nil {
		log.Fatalf("sql open: %v", err)
	}
	defer db.Close()

	driver, err := postgres.WithInstance(db, &postgres.Config{})
	if err != nil {
		log.Fatalf("migrate driver: %v", err)
	}

	m, err := migrate.NewWithInstance("iofs", src, "postgres", driver)
	if err != nil {
		log.Fatalf("migrate init: %v", err)
	}

	if err := m.Up(); err != nil && err != migrate.ErrNoChange {
		log.Fatalf("migrate up: %v", err)
	}

	shutdownTracing, err := otel.Init(cfg.ServiceName, cfg.OtelEndpoint, cfg.OtelInsecure)
	if err != nil {
		log.Fatalf("otel: %v", err)
	}
	defer func() {
		ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
		defer cancel()
		_ = shutdownTracing(ctx)
	}()

	pool, err := pgxpool.New(context.Background(), cfg.DatabaseURL)
	if err != nil {
		log.Fatalf("db: %v", err)
	}
	defer pool.Close()

	// Note: Go runtime metrics are automatically collected by Prometheus client library
	// No need for manual collection goroutine

	handler := httpapi.NewRouter(cfg, pool)

	srv := &http.Server{
		Addr:              fmt.Sprintf(":%d", cfg.Port),
		Handler:           handler,
		ReadHeaderTimeout: 5 * time.Second,
	}

	go func() {
		log.Printf("listening on :%d", cfg.Port)
		if err := srv.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			log.Fatalf("server: %v", err)
		}
	}()

	stop := make(chan os.Signal, 1)
	signal.Notify(stop, syscall.SIGINT, syscall.SIGTERM)
	<-stop

	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()
	_ = srv.Shutdown(ctx)
}
