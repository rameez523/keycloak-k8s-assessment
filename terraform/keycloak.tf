############################################
# keycloak.tf
############################################

locals {
  keycloak_tls_secret_name = "keycloak-tls"

  keycloak_ingress_annotations = merge(
    {
      "traefik.ingress.kubernetes.io/router.entrypoints" = "websecure"
      "traefik.ingress.kubernetes.io/router.tls"         = "true"
    },
    var.enable_letsencrypt ? {
      "cert-manager.io/cluster-issuer" = "letsencrypt-prod"
    } : {}
  )
}

resource "random_password" "keycloak_admin" {
  length      = 20
  special     = true
  min_upper   = 2
  min_lower   = 2
  min_numeric = 2
  min_special = 2
  override_special = "!@#%^*_+-="
}

resource "random_password" "postgres_password" {
  length  = 20
  special = false
}

resource "helm_release" "keycloak" {
  name      = "keycloak"
  namespace = kubernetes_namespace.keycloak.metadata[0].name

  repository = "oci://registry-1.docker.io/bitnamicharts"
  chart      = "keycloak"
  version    = var.keycloak_chart_version

  wait          = true
  wait_for_jobs = true
  timeout       = 600

  values = [
    yamlencode({
      global = {
        security = {
          allowInsecureImages = true
        }
      }
      image = {
        repository = "bitnamilegacy/keycloak"
      }
      volumePermissions = {
        image = {
          repository = "bitnamilegacy/os-shell"
        }
      }

      auth = {
        adminUser     = var.keycloak_admin_user
        adminPassword = random_password.keycloak_admin.result
      }

      proxy = "edge"
      httpRelativePath = "/"

      containerSecurityContext = {
        enabled                  = true
        runAsUser                = 1001
        runAsNonRoot             = true
        readOnlyRootFilesystem   = false
        allowPrivilegeEscalation = false
      }
      podSecurityContext = {
        enabled = true
        fsGroup = 1001
      }

      resources = {
        requests = { cpu = "250m", memory = "512Mi" }
        limits   = { cpu = "1",    memory = "1Gi" }
      }

      service = {
        type = "ClusterIP"
      }

      ingress = {
        enabled          = true
        ingressClassName = "traefik"
        hostname         = var.keycloak_hostname
        pathType         = "Prefix"
        annotations      = local.keycloak_ingress_annotations
        tls              = true
        extraTls = [
          {
            hosts      = [var.keycloak_hostname]
            secretName = local.keycloak_tls_secret_name
          }
        ]
      }

      postgresql = {
        enabled = true
        image = {
          repository = "bitnamilegacy/postgresql"
        }
        volumePermissions = {
          image = {
            repository = "bitnamilegacy/os-shell"
          }
        }
        metrics = {
          image = {
            repository = "bitnamilegacy/postgres-exporter"
          }
        }
        auth = {
          username = "keycloak"
          password = random_password.postgres_password.result
          database = "keycloak"
        }
        primary = {
          containerSecurityContext = {
            runAsUser    = 1001
            runAsNonRoot = true
          }
          persistence = {
            enabled = true
            size    = "2Gi"
          }
        }
      }

      metrics = {
        enabled = false
      }
    })
  ]

  depends_on = [
    kubernetes_secret.keycloak_tls,
    null_resource.cluster_issuer,
  ]
}
