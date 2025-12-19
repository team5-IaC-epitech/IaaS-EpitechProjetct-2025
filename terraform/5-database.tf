resource "google_sql_database_instance" "dev-db" {
  name = "team5-dev-sqldb"
  region = var.region
  database_version = "SQLSERVER_2019_STANDARD"
  root_password = "team5-dev-pass"
  settings {
    tier = "db-custom-2-7680"
  }
  deletion_protection = false
}