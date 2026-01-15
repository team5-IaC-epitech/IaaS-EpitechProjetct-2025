# Monitoring namespace
resource "kubernetes_namespace" "monitoring" {
  metadata {
    name = "monitoring"
    labels = {
      name = "monitoring"
    }
  }

  depends_on = [google_container_cluster.primary]
}

# Google Service Account for Grafana
resource "google_service_account" "grafana" {
  account_id   = "grafana-sa"
  display_name = "Grafana Service Account"
  description  = "Service account for Grafana to access Cloud Monitoring"
  project      = var.project_id
}

# Grant Monitoring Viewer role to Grafana SA
resource "google_project_iam_member" "grafana_monitoring_viewer" {
  project = var.project_id
  role    = "roles/monitoring.viewer"
  member  = "serviceAccount:${google_service_account.grafana.email}"
}

# Kubernetes Service Account for Grafana
resource "kubernetes_service_account" "grafana" {
  metadata {
    name      = "grafana"
    namespace = kubernetes_namespace.monitoring.metadata[0].name
    annotations = {
      "iam.gke.io/gcp-service-account" = google_service_account.grafana.email
    }
  }

  depends_on = [kubernetes_namespace.monitoring]
}

# Workload Identity binding for Grafana
resource "google_service_account_iam_member" "grafana_workload_identity" {
  service_account_id = google_service_account.grafana.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:${var.project_id}.svc.id.goog[${kubernetes_namespace.monitoring.metadata[0].name}/grafana]"
}

# Add Grafana Helm repository
resource "helm_release" "grafana" {
  name       = "grafana"
  repository = "https://grafana.github.io/helm-charts"
  chart      = "grafana"
  version    = "10.5.7"
  namespace  = kubernetes_namespace.monitoring.metadata[0].name

  wait          = true
  wait_for_jobs = true
  timeout       = 600 # 10 minutes

  values = [
    yamlencode({
      adminUser     = "admin"
      adminPassword = var.grafana_admin_password

      serviceAccount = {
        create = false
        name   = kubernetes_service_account.grafana.metadata[0].name
      }

      service = {
        type       = "ClusterIP"
        port       = 80
        targetPort = 3000
      }

      ingress = {
        enabled          = true
        ingressClassName = "gce"
        annotations = {
          "kubernetes.io/ingress.class"      = "gce"
          "kubernetes.io/ingress.allow-http" = "true"
        }
        hosts = []
        path  = "/*"
        pathType = "ImplementationSpecific"
      }

      persistence = {
        enabled          = true
        type             = "pvc"
        storageClassName = "standard-rwo"
        size             = "10Gi"
      }

      resources = {
        requests = {
          cpu    = "100m"
          memory = "256Mi"
        }
        limits = {
          cpu    = "500m"
          memory = "512Mi"
        }
      }

      datasources = {
        "datasources.yaml" = {
          apiVersion = 1
          datasources = [
            {
              name      = "Prometheus"
              type      = "prometheus"
              access    = "proxy"
              url       = "http://prometheus.monitoring.svc:9090"
              isDefault = true
              editable  = true
            },
            {
              name      = "Google Cloud Monitoring"
              type      = "stackdriver"
              access    = "proxy"
              isDefault = false
              editable  = true
              jsonData = {
                authenticationType = "gce"
                defaultProject     = var.project_id
              }
            }
          ]
        }
      }

      dashboardProviders = {
        "dashboardproviders.yaml" = {
          apiVersion = 1
          providers = [
            {
              name            = "default"
              orgId           = 1
              folder          = ""
              type            = "file"
              disableDeletion = false
              editable        = true
              options = {
                path = "/var/lib/grafana/dashboards/default"
              }
            }
          ]
        }
      }

      dashboardsConfigMaps = {
        default = kubernetes_config_map.grafana_dashboards.metadata[0].name
      }

      securityContext = {
        runAsUser    = 472
        runAsGroup   = 472
        fsGroup      = 472
        runAsNonRoot = true
      }

      podSecurityContext = {
        runAsUser    = 472
        runAsGroup   = 472
        fsGroup      = 472
        runAsNonRoot = true
      }

      env = {
        GF_SERVER_ROOT_URL            = "http://grafana.local"
        GF_USERS_ALLOW_SIGN_UP        = "false"
        GF_AUTH_ANONYMOUS_ENABLED     = "false"
      }

      readinessProbe = {
        httpGet = {
          path = "/api/health"
          port = 3000
        }
        initialDelaySeconds = 10
        periodSeconds       = 10
      }

      livenessProbe = {
        httpGet = {
          path = "/api/health"
          port = 3000
        }
        initialDelaySeconds = 30
        periodSeconds       = 10
      }
    })
  ]

  depends_on = [
    kubernetes_namespace.monitoring,
    kubernetes_config_map.grafana_dashboards,
    kubernetes_service_account.grafana,
    google_service_account.grafana,
    google_project_iam_member.grafana_monitoring_viewer,
    google_service_account_iam_member.grafana_workload_identity,
    kubernetes_service.prometheus,
    google_container_cluster.primary
  ]
}

# Grafana dashboards ConfigMap
resource "kubernetes_config_map" "grafana_dashboards" {
  metadata {
    name      = "grafana-dashboards"
    namespace = kubernetes_namespace.monitoring.metadata[0].name
  }

  data = {
    "task-manager-overview.json" = file("${path.module}/../helm/grafana/dashboards/task-manager-overview.json")
  }

  depends_on = [kubernetes_namespace.monitoring]
}

# Note: PodMonitoring resource is managed by the Helm chart at helm/task-manager/templates/podmonitoring.yaml

# Prometheus ConfigMap
resource "kubernetes_config_map" "prometheus_config" {
  metadata {
    name      = "prometheus-config"
    namespace = kubernetes_namespace.monitoring.metadata[0].name
  }

  data = {
    "prometheus.yml" = <<-EOT
      global:
        scrape_interval: 30s
        evaluation_interval: 30s

      alerting:
        alertmanagers:
          - static_configs:
              - targets:
                  - alertmanager:9093

      rule_files:
        - /etc/prometheus/alert-rules.yaml

      scrape_configs:
        - job_name: 'task-manager'
          kubernetes_sd_configs:
            - role: pod
              namespaces:
                names:
                  - default
          relabel_configs:
            - source_labels: [__meta_kubernetes_pod_label_app_kubernetes_io_name]
              action: keep
              regex: task-manager
            - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_scrape]
              action: keep
              regex: true
            - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_path]
              action: replace
              target_label: __metrics_path__
              regex: (.+)
            - source_labels: [__address__, __meta_kubernetes_pod_annotation_prometheus_io_port]
              action: replace
              regex: ([^:]+)(?::\d+)?;(\d+)
              replacement: $1:$2
              target_label: __address__
            - action: labelmap
              regex: __meta_kubernetes_pod_label_(.+)
            - source_labels: [__meta_kubernetes_namespace]
              action: replace
              target_label: kubernetes_namespace
            - source_labels: [__meta_kubernetes_pod_name]
              action: replace
              target_label: kubernetes_pod_name
    EOT

    "alert-rules.yaml" = file("${path.module}/../helm/prometheus-alerts/alert-rules.yaml")
  }

  depends_on = [kubernetes_namespace.monitoring]
}

# Prometheus ServiceAccount
resource "kubernetes_service_account" "prometheus" {
  metadata {
    name      = "prometheus"
    namespace = kubernetes_namespace.monitoring.metadata[0].name
  }

  depends_on = [kubernetes_namespace.monitoring]
}

# Prometheus ClusterRole
resource "kubernetes_cluster_role" "prometheus" {
  metadata {
    name = "prometheus"
  }

  rule {
    api_groups = [""]
    resources  = ["nodes", "nodes/proxy", "services", "endpoints", "pods"]
    verbs      = ["get", "list", "watch"]
  }

  rule {
    api_groups = ["extensions"]
    resources  = ["ingresses"]
    verbs      = ["get", "list", "watch"]
  }
}

# Prometheus ClusterRoleBinding
resource "kubernetes_cluster_role_binding" "prometheus" {
  metadata {
    name = "prometheus"
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = kubernetes_cluster_role.prometheus.metadata[0].name
  }

  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account.prometheus.metadata[0].name
    namespace = kubernetes_namespace.monitoring.metadata[0].name
  }
}

# Prometheus Service
resource "kubernetes_service" "prometheus" {
  metadata {
    name      = "prometheus"
    namespace = kubernetes_namespace.monitoring.metadata[0].name
    annotations = {
      "cloud.google.com/backend-config" = jsonencode({
        ports = {
          "web" = "prometheus-backend-config"
        }
      })
    }
  }

  spec {
    selector = {
      app = "prometheus"
    }

    port {
      name        = "web"
      port        = 9090
      target_port = 9090
      node_port   = 30090
    }

    type = "NodePort"
  }

  depends_on = [kubernetes_namespace.monitoring]
}

# Prometheus Deployment
resource "kubernetes_deployment" "prometheus" {
  metadata {
    name      = "prometheus"
    namespace = kubernetes_namespace.monitoring.metadata[0].name
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "prometheus"
      }
    }

    template {
      metadata {
        labels = {
          app = "prometheus"
        }
      }

      spec {
        service_account_name = kubernetes_service_account.prometheus.metadata[0].name

        container {
          name  = "prometheus"
          image = "prom/prometheus:latest"

          args = [
            "--config.file=/etc/prometheus/prometheus.yml",
            "--storage.tsdb.path=/prometheus",
            "--web.enable-lifecycle"
          ]

          port {
            container_port = 9090
          }

          volume_mount {
            name       = "config"
            mount_path = "/etc/prometheus"
            read_only  = true
          }

          volume_mount {
            name       = "storage"
            mount_path = "/prometheus"
          }

          resources {
            requests = {
              cpu    = "200m"
              memory = "512Mi"
            }
            limits = {
              cpu    = "1000m"
              memory = "2Gi"
            }
          }
        }

        volume {
          name = "config"
          config_map {
            name = kubernetes_config_map.prometheus_config.metadata[0].name
          }
        }

        volume {
          name = "storage"
          empty_dir {}
        }
      }
    }
  }

  depends_on = [
    kubernetes_namespace.monitoring,
    kubernetes_config_map.prometheus_config,
    kubernetes_service_account.prometheus,
    kubernetes_cluster_role_binding.prometheus
  ]

  lifecycle {
    ignore_changes = [
      metadata[0].annotations,
      spec[0].template[0].spec[0].container[0].resources,
      spec[0].template[0].spec[0].container[0].security_context,
      spec[0].template[0].spec[0].security_context,
      spec[0].template[0].spec[0].toleration
    ]
  }
}

# AlertManager ConfigMap
resource "kubernetes_config_map" "alertmanager_config" {
  metadata {
    name      = "alertmanager-config"
    namespace = kubernetes_namespace.monitoring.metadata[0].name
  }

  data = {
    "alertmanager.yml" = <<-EOT
      global:
        resolve_timeout: 5m

      route:
        group_by: ['alertname', 'severity']
        group_wait: 10s
        group_interval: 10s
        repeat_interval: 12h
        receiver: 'default'

      receivers:
        - name: 'default'
          # Configure your notification channel here (Slack, Email, PagerDuty, etc.)
          # For now, alerts will be visible in AlertManager UI
    EOT
  }

  depends_on = [kubernetes_namespace.monitoring]
}

# AlertManager Service
resource "kubernetes_service" "alertmanager" {
  metadata {
    name      = "alertmanager"
    namespace = kubernetes_namespace.monitoring.metadata[0].name
  }

  spec {
    selector = {
      app = "alertmanager"
    }

    port {
      name        = "web"
      port        = 9093
      target_port = 9093
      node_port   = 30093
    }

    type = "NodePort"
  }

  depends_on = [kubernetes_namespace.monitoring]
}

# AlertManager Deployment
resource "kubernetes_deployment" "alertmanager" {
  metadata {
    name      = "alertmanager"
    namespace = kubernetes_namespace.monitoring.metadata[0].name
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "alertmanager"
      }
    }

    template {
      metadata {
        labels = {
          app = "alertmanager"
        }
      }

      spec {
        container {
          name  = "alertmanager"
          image = "prom/alertmanager:latest"

          args = [
            "--config.file=/etc/alertmanager/alertmanager.yml",
            "--storage.path=/alertmanager"
          ]

          port {
            container_port = 9093
          }

          volume_mount {
            name       = "config"
            mount_path = "/etc/alertmanager"
            read_only  = true
          }

          volume_mount {
            name       = "storage"
            mount_path = "/alertmanager"
          }

          resources {
            requests = {
              cpu    = "50m"
              memory = "128Mi"
            }
            limits = {
              cpu    = "200m"
              memory = "256Mi"
            }
          }
        }

        volume {
          name = "config"
          config_map {
            name = kubernetes_config_map.alertmanager_config.metadata[0].name
          }
        }

        volume {
          name = "storage"
          empty_dir {}
        }
      }
    }
  }

  depends_on = [
    kubernetes_namespace.monitoring,
    kubernetes_config_map.alertmanager_config
  ]
}

# Prometheus BackendConfig for health check
resource "kubernetes_manifest" "prometheus_backend_config" {
  manifest = {
    apiVersion = "cloud.google.com/v1"
    kind       = "BackendConfig"
    metadata = {
      name      = "prometheus-backend-config"
      namespace = kubernetes_namespace.monitoring.metadata[0].name
    }
    spec = {
      healthCheck = {
        requestPath = "/-/healthy"
        port        = 9090
        type        = "HTTP"
      }
    }
  }

  depends_on = [kubernetes_namespace.monitoring]
}

# Prometheus Ingress
resource "kubernetes_ingress_v1" "prometheus" {
  metadata {
    name      = "prometheus"
    namespace = kubernetes_namespace.monitoring.metadata[0].name
    annotations = {
      "kubernetes.io/ingress.class" = "gce"
    }
  }

  spec {
    ingress_class_name = "gce"

    rule {
      http {
        path {
          path      = "/*"
          path_type = "ImplementationSpecific"

          backend {
            service {
              name = kubernetes_service.prometheus.metadata[0].name
              port {
                number = 9090
              }
            }
          }
        }
      }
    }
  }

  depends_on = [
    kubernetes_namespace.monitoring,
    kubernetes_service.prometheus
  ]
}

# AlertManager Ingress
resource "kubernetes_ingress_v1" "alertmanager" {
  metadata {
    name      = "alertmanager"
    namespace = kubernetes_namespace.monitoring.metadata[0].name
    annotations = {
      "kubernetes.io/ingress.class" = "gce"
    }
  }

  spec {
    ingress_class_name = "gce"

    rule {
      http {
        path {
          path      = "/*"
          path_type = "ImplementationSpecific"

          backend {
            service {
              name = kubernetes_service.alertmanager.metadata[0].name
              port {
                number = 9093
              }
            }
          }
        }
      }
    }
  }

  depends_on = [
    kubernetes_namespace.monitoring,
    kubernetes_service.alertmanager
  ]
}
