# Cloud SQL PostgreSQL instance (production-grade configuration)
resource "google_sql_database_instance" "postgres" {
  name             = "${var.cluster_name}-postgres-${var.environment}"
  database_version = "POSTGRES_16"
  region           = var.region
  project          = var.project_id

  deletion_protection = false

  settings {
    tier = var.cloudsql_tier

    # REGIONAL for high availability in production, ZONAL for dev
    availability_type = var.environment == "prd" ? "REGIONAL" : "ZONAL"

    disk_type             = "PD_SSD"
    disk_size             = var.cloudsql_disk_size
    disk_autoresize       = true
    disk_autoresize_limit = var.environment == "prd" ? 100 : 50

    # Backup configuration
    backup_configuration {
      enabled                        = true
      start_time                     = "03:00" # 3 AM UTC
      point_in_time_recovery_enabled = var.environment == "prd" ? true : false
      transaction_log_retention_days = var.environment == "prd" ? 7 : 3

      backup_retention_settings {
        retained_backups = var.environment == "prd" ? 30 : 7
        retention_unit   = "COUNT"
      }
    }

    # Maintenance window (Sunday 4-5 AM UTC)
    maintenance_window {
      day          = 7 # Sunday
      hour         = 4
      update_track = "stable"
    }

    # Private IP configuration (no public IP)
    ip_configuration {
      ipv4_enabled                                  = false # CRITICAL: No public IP
      private_network                               = google_compute_network.vpc_network.id
      enable_private_path_for_google_cloud_services = true
      ssl_mode                                      = "ENCRYPTED_ONLY"
    }

    # Database flags
    database_flags {
      name  = "max_connections"
      value = var.environment == "prd" ? "200" : "100"
    }

    database_flags {
      name  = "shared_buffers"
      value = "32768"
    }

    database_flags {
      name  = "log_checkpoints"
      value = "on"
    }

    database_flags {
      name  = "log_connections"
      value = "on"
    }

    database_flags {
      name  = "log_disconnections"
      value = "on"
    }

    database_flags {
      name  = "log_lock_waits"
      value = "on"
    }

    # Query insights for performance monitoring
    insights_config {
      query_insights_enabled  = true
      query_string_length     = 1024
      record_application_tags = true
      record_client_address   = true
    }

    # User labels for cost tracking
    user_labels = {
      environment = var.environment
      managed_by  = "terraform"
      application = var.app_name
      team        = "team5"
    }
  }

  depends_on = [google_service_networking_connection.private_vpc_connection]
}

# Create database
resource "google_sql_database" "database" {
  name     = var.cloudsql_database_name
  instance = google_sql_database_instance.postgres.name
  project  = var.project_id

  # UTF8 encoding for proper character support
  charset   = "UTF8"
  collation = "en_US.UTF8"
}

# Create random password for database user (32 chars, high entropy)
resource "random_password" "db_password" {
  length  = 32
  special = true

  # Ensure password complexity
  min_lower   = 4
  min_upper   = 4
  min_numeric = 4
  min_special = 4
}

# Create database user
resource "google_sql_user" "db_user" {
  name     = var.cloudsql_user_name
  instance = google_sql_database_instance.postgres.name
  password = random_password.db_password.result
  project  = var.project_id

  # User type for CloudSQL
  type = "BUILT_IN"
}
