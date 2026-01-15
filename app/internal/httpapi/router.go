package httpapi

import (
	"net/http"

	"github.com/gin-gonic/gin"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/prometheus/client_golang/prometheus/promhttp"

	"team5/task-manager/internal/config"
	"team5/task-manager/internal/httpapi/handlers"
	"team5/task-manager/internal/httpapi/middleware"
	"team5/task-manager/internal/store/postgres"
)

func NewRouter(cfg *config.Config, pool *pgxpool.Pool) http.Handler {
	gin.SetMode(gin.ReleaseMode)
	r := gin.New()

	r.Use(gin.Recovery())
	r.Use(middleware.CorrelationID())
	r.Use(middleware.PrometheusMetrics())

	r.GET("/healthz", func(c *gin.Context) { c.Status(http.StatusOK) })
	r.GET("/readyz", func(c *gin.Context) { c.Status(http.StatusOK) })
	r.GET("/metrics", gin.WrapH(promhttp.Handler()))

	api := r.Group("/")
	api.Use(middleware.AuthJWT(cfg.JWTSecret))

	store := postgres.NewTasksStore(pool)
	tasks := handlers.NewTasksHandler(store)

	api.POST("/tasks", tasks.Create)
	api.GET("/tasks", tasks.List)
	api.GET("/tasks/:id", tasks.Get)
	api.PUT("/tasks/:id", tasks.Update)
	api.DELETE("/tasks/:id", tasks.Delete)

	_ = pool

	return r
}
