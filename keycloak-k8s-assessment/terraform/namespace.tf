############################################
# namespace.tf
############################################

resource "kubernetes_namespace" "keycloak" {
  metadata {
    name = var.namespace

    labels = {
      "app.kubernetes.io/managed-by" = "terraform"
      "pod-security.kubernetes.io/enforce" = "baseline"
      "pod-security.kubernetes.io/warn"    = "restricted"
    }
  }

  depends_on = [time_sleep.wait_for_traefik]
}
