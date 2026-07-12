############################################
# network-policy.tf
# Basic network hardening: deny-all by default in the keycloak namespace,
# then explicitly allow only the traffic the app actually needs:
#   - Ingress: from Traefik (kube-system) on the Keycloak HTTP port only
#   - Egress : DNS resolution, and Postgres within the same namespace
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
