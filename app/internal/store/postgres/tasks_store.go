package postgres

import (
	"context"
	"errors"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"

	"team5/task-manager/internal/model"
)

var (
	ErrNotFound = errors.New("not found")
	ErrConflict = errors.New("conflict")
)

type TasksStore struct {
	pool *pgxpool.Pool
}

func NewTasksStore(pool *pgxpool.Pool) *TasksStore {
	return &TasksStore{pool: pool}
}

func (s *TasksStore) Create(ctx context.Context, title, content string, dueDate time.Time, reqTS time.Time) (model.Task, error) {
	var t model.Task
	row := s.pool.QueryRow(ctx, `
		INSERT INTO tasks (title, content, due_date, done, last_request_timestamp)
		VALUES ($1, $2, $3, false, $4)
		RETURNING id::text, title, content, to_char(due_date,'YYYY-MM-DD'), done,
		          last_request_timestamp, created_at, updated_at
	`, title, content, dueDate, reqTS)

	err := row.Scan(&t.ID, &t.Title, &t.Content, &t.DueDate, &t.Done, &t.LastRequestTimestamp, &t.CreatedAt, &t.UpdatedAt)
	return t, err
}

func (s *TasksStore) List(ctx context.Context) ([]model.Task, error) {
	rows, err := s.pool.Query(ctx, `
		SELECT id::text, title, content, to_char(due_date,'YYYY-MM-DD'), done,
		       last_request_timestamp, created_at, updated_at
		FROM tasks
		ORDER BY created_at DESC
	`)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var out []model.Task
	for rows.Next() {
		var t model.Task
		if err := rows.Scan(&t.ID, &t.Title, &t.Content, &t.DueDate, &t.Done, &t.LastRequestTimestamp, &t.CreatedAt, &t.UpdatedAt); err != nil {
			return nil, err
		}
		out = append(out, t)
	}
	return out, rows.Err()
}

func (s *TasksStore) Get(ctx context.Context, id string) (model.Task, error) {
	var t model.Task
	row := s.pool.QueryRow(ctx, `
		SELECT id::text, title, content, to_char(due_date,'YYYY-MM-DD'), done,
		       last_request_timestamp, created_at, updated_at
		FROM tasks
		WHERE id = $1
	`, id)

	if err := row.Scan(&t.ID, &t.Title, &t.Content, &t.DueDate, &t.Done, &t.LastRequestTimestamp, &t.CreatedAt, &t.UpdatedAt); err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return model.Task{}, ErrNotFound
		}
		return model.Task{}, err
	}
	return t, nil
}

func (s *TasksStore) Update(ctx context.Context, id string, patch model.UpdateTaskRequest, dueDate *time.Time, reqTS time.Time) (model.Task, error) {
	tx, err := s.pool.BeginTx(ctx, pgx.TxOptions{})
	if err != nil {
		return model.Task{}, err
	}
	defer func() { _ = tx.Rollback(ctx) }()

	var lastTS time.Time
	err = tx.QueryRow(ctx, `SELECT last_request_timestamp FROM tasks WHERE id = $1 FOR UPDATE`, id).Scan(&lastTS)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return model.Task{}, ErrNotFound
		}
		return model.Task{}, err
	}
	if !reqTS.After(lastTS) {
		return model.Task{}, ErrConflict
	}

	// patch partiel avec COALESCE
	_, err = tx.Exec(ctx, `
		UPDATE tasks SET
		  title = COALESCE($2, title),
		  content = COALESCE($3, content),
		  due_date = COALESCE($4, due_date),
		  done = COALESCE($5, done),
		  last_request_timestamp = $6,
		  updated_at = now()
		WHERE id = $1
	`, id, patch.Title, patch.Content, dueDate, patch.Done, reqTS)
	if err != nil {
		return model.Task{}, err
	}

	var t model.Task
	row := tx.QueryRow(ctx, `
		SELECT id::text, title, content, to_char(due_date,'YYYY-MM-DD'), done,
		       last_request_timestamp, created_at, updated_at
		FROM tasks WHERE id = $1
	`, id)
	if err := row.Scan(&t.ID, &t.Title, &t.Content, &t.DueDate, &t.Done, &t.LastRequestTimestamp, &t.CreatedAt, &t.UpdatedAt); err != nil {
		return model.Task{}, err
	}

	if err := tx.Commit(ctx); err != nil {
		return model.Task{}, err
	}
	return t, nil
}

func (s *TasksStore) Delete(ctx context.Context, id string, reqTS time.Time) error {
	tx, err := s.pool.BeginTx(ctx, pgx.TxOptions{})
	if err != nil {
		return err
	}
	defer func() { _ = tx.Rollback(ctx) }()

	var lastTS time.Time
	err = tx.QueryRow(ctx, `SELECT last_request_timestamp FROM tasks WHERE id = $1 FOR UPDATE`, id).Scan(&lastTS)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return ErrNotFound
		}
		return err
	}
	if !reqTS.After(lastTS) {
		return ErrConflict
	}

	_, err = tx.Exec(ctx, `DELETE FROM tasks WHERE id = $1`, id)
	if err != nil {
		return err
	}

	return tx.Commit(ctx)
}
