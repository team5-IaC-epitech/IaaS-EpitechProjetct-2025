# GitHub Actions Self-Hosted Runners using Actions Runner Controller (ARC)
# https://github.com/actions/actions-runner-controller
#
# Local: terraform plan validates syntax (runners skipped - no credentials)
# CI/CD: terraform apply deploys runners (credentials from GitHub Secrets)

locals {
  deploy_runners = (
    var.github_app_id != "" &&
    var.github_app_installation_id != "" &&
    var.github_app_private_key != ""
  )
}


# Namespace for ARC controller
resource "kubernetes_namespace" "arc_system" {
  count = local.deploy_runners ? 1 : 0

  metadata {
    name = "arc-system"
  }

  depends_on = [google_container_cluster.primary]
}

# Namespace for runners
resource "kubernetes_namespace" "arc_runners" {
  count = local.deploy_runners ? 1 : 0

  metadata {
    name = "arc-runners"
  }

  depends_on = [google_container_cluster.primary]
}

# Secret for GitHub App authentication
resource "kubernetes_secret" "github_app_secret" {
  count = local.deploy_runners ? 1 : 0

  metadata {
    name      = "github-app-secret"
    namespace = kubernetes_namespace.arc_runners[0].metadata[0].name
  }

  data = {
    github_app_id              = var.github_app_id
    github_app_installation_id = var.github_app_installation_id
    github_app_private_key     = var.github_app_private_key
  }

  type = "Opaque"
}

# Actions Runner Controller - Controller deployment
resource "helm_release" "arc_controller" {
  count = local.deploy_runners ? 1 : 0

  name       = "arc"
  repository = "oci://ghcr.io/actions/actions-runner-controller-charts"
  chart      = "gha-runner-scale-set-controller"
  version    = "0.9.3"
  namespace  = kubernetes_namespace.arc_system[0].metadata[0].name

  wait    = true
  timeout = 300

  depends_on = [
    kubernetes_namespace.arc_system,
    google_container_cluster.primary
  ]
}

# RBAC: Allow ARC controller to access secrets in arc-runners namespace
resource "kubernetes_role" "arc_controller_secrets" {
  count = local.deploy_runners ? 1 : 0

  metadata {
    name      = "arc-controller-secrets"
    namespace = kubernetes_namespace.arc_runners[0].metadata[0].name
  }

  rule {
    api_groups = [""]
    resources  = ["secrets", "pods", "serviceaccounts"]
    verbs      = ["get", "list", "watch", "create", "update", "patch", "delete"]
  }

  rule {
    api_groups = [""]
    resources  = ["pods/exec"]
    verbs      = ["create"]
  }

  rule {
    api_groups = ["rbac.authorization.k8s.io"]
    resources  = ["roles", "rolebindings"]
    verbs      = ["get", "list", "watch", "create", "update", "patch", "delete"]
  }

  rule {
    api_groups = ["actions.github.com"]
    resources  = ["ephemeralrunnersets", "ephemeralrunners", "ephemeralrunners/status"]
    verbs      = ["get", "list", "watch", "create", "update", "patch", "delete"]
  }
}

resource "kubernetes_role_binding" "arc_controller_secrets" {
  count = local.deploy_runners ? 1 : 0

  metadata {
    name      = "arc-controller-secrets"
    namespace = kubernetes_namespace.arc_runners[0].metadata[0].name
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "Role"
    name      = kubernetes_role.arc_controller_secrets[0].metadata[0].name
  }

  subject {
    kind      = "ServiceAccount"
    name      = "arc-gha-rs-controller"
    namespace = "arc-system"
  }
}

# Runner Scale Set - The actual runners
resource "helm_release" "arc_runner_set" {
  count = local.deploy_runners ? 1 : 0

  name       = "arc-runner-set"
  repository = "oci://ghcr.io/actions/actions-runner-controller-charts"
  chart      = "gha-runner-scale-set"
  version    = "0.9.3"
  namespace  = kubernetes_namespace.arc_runners[0].metadata[0].name

  values = [
    templatefile("${path.module}/helm-values/arc-runner-values.yaml", {
      github_config_url          = var.github_config_url
      github_app_id              = var.github_app_id
      github_app_installation_id = var.github_app_installation_id
      min_runners                = var.arc_min_runners
      max_runners                = var.arc_max_runners
    })
  ]

  set_sensitive {
    name  = "githubConfigSecret.github_app_private_key"
    value = var.github_app_private_key
  }

  wait    = true
  timeout = 300

  depends_on = [
    helm_release.arc_controller,
    kubernetes_secret.github_app_secret,
    kubernetes_namespace.arc_runners,
    kubernetes_role_binding.arc_controller_secrets
  ]
}
