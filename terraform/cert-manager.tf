############################################
# cert-manager.tf
#
# Optional (enable_letsencrypt = true): installs cert-manager and a
# ClusterIssuer for Let's Encrypt's production ACME endpoint, using the
# HTTP-01 challenge type via the Traefik ingress already running in the
# cluster. All resources here are count-gated to 0 when disabled.
############################################

resource "helm_release" "cert_manager" {
  count = var.enable_letsencrypt ? 1 : 0

  name             = "cert-manager"
  namespace        = "cert-manager"
  create_namespace = true
  repository       = "https://charts.jetstack.io"
  chart            = "cert-manager"
  version          = var.cert_manager_chart_version

  set {
    name  = "installCRDs"
    value = "true"
  }

  wait    = true
  timeout = 300

  depends_on = [time_sleep.wait_for_traefik]
}

resource "time_sleep" "wait_for_cert_manager_webhook" {
  count           = var.enable_letsencrypt ? 1 : 0
  create_duration = "20s"
  depends_on      = [helm_release.cert_manager]
}

resource "null_resource" "cluster_issuer" {
  count = var.enable_letsencrypt ? 1 : 0

  triggers = {
    email = var.acme_email
  }

  provisioner "local-exec" {
    command = <<-EOT
      set -euo pipefail
      export KUBECONFIG="${path.module}/.kube/config"
      cat <<YAML | kubectl apply -f -
      apiVersion: cert-manager.io/v1
      kind: ClusterIssuer
      metadata:
        name: letsencrypt-prod
      spec:
        acme:
          email: ${var.acme_email}
          server: https://acme-v02.api.letsencrypt.org/directory
          privateKeySecretRef:
            name: letsencrypt-prod
          solvers:
            - http01:
                ingress:
                  class: traefik
      YAML
    EOT
  }

  provisioner "local-exec" {
    when    = destroy
    command = "export KUBECONFIG=\"${path.module}/.kube/config\"; kubectl delete clusterissuer letsencrypt-prod --ignore-not-found || true"
  }

  depends_on = [time_sleep.wait_for_cert_manager_webhook]
}
