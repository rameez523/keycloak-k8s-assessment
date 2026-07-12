############################################
# network-policy.tf
# Basic network hardening: deny-all by default in the keycloak namespace,
# then explicitly allow only the traffic the app actually needs.
############################################

resource "kubernetes_network_policy" "default_deny_all" {
  metadata {
    name      = "default-deny-all"
    namespace = kubernetes_namespace.keycloak.metadata[0].name
  }

  spec {
    pod_selector {}
    policy_types = ["Ingress", "Egress"]
  }
}

resource "kubernetes_network_policy" "allow_ingress_from_traefik" {
  metadata {
    name      = "allow-ingress-from-traefik"
    namespace = kubernetes_namespace.keycloak.metadata[0].name
  }

  spec {
    pod_selector {
      match_labels = {
        "app.kubernetes.io/name" = "keycloak"
      }
    }

    policy_types = ["Ingress"]

    ingress {
      from {
        namespace_selector {
          match_labels = {
            "kubernetes.io/metadata.name" = "kube-system"
          }
        }
      }
      ports {
        port     = 8080
        protocol = "TCP"
      }
    }
  }
}

resource "kubernetes_network_policy" "allow_egress_dns" {
  metadata {
    name      = "allow-egress-dns"
    namespace = kubernetes_namespace.keycloak.metadata[0].name
  }

  spec {
    pod_selector {}
    policy_types = ["Egress"]

    egress {
      to {
        namespace_selector {
          match_labels = {
            "kubernetes.io/metadata.name" = "kube-system"
          }
        }
      }
      ports {
        port     = 53
        protocol = "UDP"
      }
      ports {
        port     = 53
        protocol = "TCP"
      }
    }
  }
}

resource "kubernetes_network_policy" "allow_egress_keycloak_to_postgres" {
  metadata {
    name      = "allow-egress-keycloak-to-postgres"
    namespace = kubernetes_namespace.keycloak.metadata[0].name
  }

  spec {
    pod_selector {
      match_labels = {
        "app.kubernetes.io/name" = "keycloak"
      }
    }

    policy_types = ["Egress"]

    egress {
      to {
        pod_selector {
          match_labels = {
            "app.kubernetes.io/name" = "postgresql"
          }
        }
      }
      ports {
        port     = 5432
        protocol = "TCP"
      }
    }
  }
}

resource "kubernetes_network_policy" "allow_ingress_acme_solver" {
  # Only needed when Let's Encrypt is enabled: cert-manager's HTTP-01
  # challenge spins up a temporary solver pod in this same namespace,
  # which Traefik must be able to reach to complete domain validation.
  count = var.enable_letsencrypt ? 1 : 0

  metadata {
    name      = "allow-ingress-acme-solver"
    namespace = kubernetes_namespace.keycloak.metadata[0].name
  }

  spec {
    pod_selector {
      match_labels = {
        "acme.cert-manager.io/http01-solver" = "true"
      }
    }

    policy_types = ["Ingress"]

    ingress {
      from {
        namespace_selector {
          match_labels = {
            "kubernetes.io/metadata.name" = "kube-system"
          }
        }
      }
    }
  }
}

resource "kubernetes_network_policy" "allow_keycloak_to_postgres" {
  metadata {
    name      = "allow-keycloak-to-postgres"
    namespace = kubernetes_namespace.keycloak.metadata[0].name
  }

  spec {
    pod_selector {
      match_labels = {
        "app.kubernetes.io/name" = "postgresql"
      }
    }

    policy_types = ["Ingress"]

    ingress {
      from {
        pod_selector {
          match_labels = {
            "app.kubernetes.io/name" = "keycloak"
          }
        }
      }
      ports {
        port     = 5432
        protocol = "TCP"
      }
    }
  }
}
