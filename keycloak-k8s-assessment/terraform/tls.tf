############################################
# tls.tf
# Self-signed TLS certificate so Keycloak is only ever reachable over
# HTTPS. For a local/assessment cluster with no public DNS name, a
# self-signed cert (rather than e.g. Let's Encrypt, which needs public
# domain validation) is the standard approach; cert-manager could swap
# this out for a real CA with zero changes to keycloak.tf.
############################################

resource "tls_private_key" "keycloak" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "tls_self_signed_cert" "keycloak" {
  private_key_pem = tls_private_key.keycloak.private_key_pem

  subject {
    common_name  = var.keycloak_hostname
    organization = "Keycloak Assessment"
  }

  dns_names = [
    var.keycloak_hostname,
    "localhost",
  ]

  validity_period_hours = 8760 # 1 year
  early_renewal_hours    = 720

  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "server_auth",
  ]
}

resource "kubernetes_secret" "keycloak_tls" {
  metadata {
    name      = "keycloak-tls"
    namespace = kubernetes_namespace.keycloak.metadata[0].name
  }

  type = "kubernetes.io/tls"

  data = {
    "tls.crt" = tls_self_signed_cert.keycloak.cert_pem
    "tls.key" = tls_private_key.keycloak.private_key_pem
  }

  depends_on = [time_sleep.wait_for_traefik]
}
