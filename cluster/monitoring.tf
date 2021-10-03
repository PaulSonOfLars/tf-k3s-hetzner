resource "random_password" "grafana_db_password" {
  length  = 16
  special = false
}

resource "random_password" "grafana_root_password" {
  length  = 16
  special = false
}

resource "kubernetes_secret" "grafana-secrets" {
  metadata {
    name      = "grafana-secret"
    namespace = "monitoring"
  }

  data = {
    DATABASE_USER : "grafana-db-user"
    DATABASE_PASSWORD : random_password.grafana_db_password.result
    SECURITY_ADMIN_PASSWORD : random_password.grafana_root_password.result
  }
}

data "kustomization_build" "monitoring" {
  path = "kustomizations/monitoring"
}

resource "kustomization_resource" "monitoring" {
  for_each = data.kustomization_build.monitoring.ids

  manifest = data.kustomization_build.monitoring.manifests[each.value]
}
