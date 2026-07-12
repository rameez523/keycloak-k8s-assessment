############################################
# keycloak.tf
############################################

resource "random_password" "keycloak_admin" {
  length      = 20
  special     = true
  min_upper   = 2
  min_lower   = 2
  min_numeric = 2
  min_special = 2
  # Avoid characters that are awkward in shells / Helm --set strings
  override_special = "!@#%^*_+-="
}

resource "random_password" "postgres_password" {
  length  = 20
  special = false
}

resource "helm_release" "keycloak" {
  name      = "keycloak"
  namespace = kubernetes_namespace.keycloak.metadata[0].name

  # Bitnami now distributes charts primarily via OCI; pulling "keycloak"
  # from the classic https://charts.bitnami.com/bitnami repo can fail to
  # resolve its (also OCI-hosted) bundled PostgreSQL sub-dependency via
  # Terraform's helm provider ("invalid_reference: invalid tag"). The OCI
  # path below resolves cleanly.
  repository = "oci://registry-1.docker.io/bitnamicharts"
  chart      = "keycloak"
  version    = var.keycloak_chart_version

  # Wait for all pods (Keycloak + bundled Postgres) to be Ready before
  # Terraform reports success, so `terraform apply` only exits 0 once the
  # instance is actually usable.
  wait          = true
  wait_for_jobs = true
  timeout       = 600

  values = [
    yamlencode({
      # --- Bitnami image registry workaround -------------------------
      # Since Aug 2025, Bitnami only publishes the "latest" tag to the
      # free docker.io/bitnami/* org; specific version tags (which this
      # chart references, e.g. keycloak:26.3.3-debian-12-r0) 404. Bitnami's
      # documented workaround is to pull the same frozen images from the
      # docker.io/bitnamilegacy/* org instead, and set
      # global.security.allowInsecureImages=true so the chart doesn't
      # reject the registry mismatch.
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

      # Keycloak sits behind Traefik, which terminates TLS at the edge and
      # forwards plain HTTP internally -- tell Keycloak to trust those
      # X-Forwarded-* headers rather than expose it to raw internet traffic
      # directly.
      proxy = "edge"

      httpRelativePath = "/"

      # --- Security hardening ---------------------------------------
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

      # Only ClusterIP internally -- the ONLY externally reachable path is
      # the Ingress below, over HTTPS.
      service = {
        type = "ClusterIP"
      }

      ingress = {
        enabled          = true
        ingressClassName = "traefik"
        hostname         = var.keycloak_hostname
        pathType         = "Prefix"
        annotations = {
          "traefik.ingress.kubernetes.io/router.entrypoints" = "websecure"
          "traefik.ingress.kubernetes.io/router.tls"         = "true"
        }
        tls = true
        extraTls = [
          {
            hosts      = [var.keycloak_hostname]
            secretName = kubernetes_secret.keycloak_tls.metadata[0].name
          }
        ]
      }

      # --- Bundled PostgreSQL (persistence for realms/users) ----------
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
  ]
}
