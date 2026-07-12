############################################
# tls.tf
# Self-signed TLS certificate so Keycloak is only ever reachable over
# HTTPS. Used by default; skipped entirely (count = 0) when
# enable_letsencrypt = true, in which case cert-manager (cert-manager.tf)
# populates the same "keycloak-tls" secret name with a real Let's Encrypt
# certificate instead.
############################################

resource "tls_private_key" "keycloak" {
  count = var.enable_letsencrypt ? 0 : 1

  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "tls_self_signed_cert" "keycloak" {
  count = var.enable_letsencrypt ? 0 : 1

  private_key_pem = tls_private_key.keycloak[0].private_key_pem

  subject {
    common_name  = var.keycloak_hostname
    organization = "Keycloak Assessment"
  }

  dns_names = [
    var.keycloak_hostname,
    "localhost",
  ]

  validity_period_hours = 8760
  early_renewal_hours    = 720

  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "server_auth",
  ]
}

resource "kubernetes_secret" "keycloak_tls" {
  count = var.enable_letsencrypt ? 0 : 1

  metadata {
    name      = "keycloak-tls"
    namespace = kubernetes_namespace.keycloak.metadata[0].name
  }

  type = "kubernetes.io/tls"

  data = {
    "tls.crt" = tls_self_signed_cert.keycloak[0].cert_pem
    "tls.key" = tls_private_key.keycloak[0].private_key_pem
  }

  depends_on = [time_sleep.wait_for_traefik]
}
