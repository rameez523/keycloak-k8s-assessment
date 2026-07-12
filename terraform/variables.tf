############################################
# variables.tf
############################################

variable "cluster_name" {
  description = "Name of the local k3d/k3s cluster"
  type        = string
  default     = "keycloak-assessment"
}

variable "k3d_agents" {
  description = "Number of k3d worker (agent) nodes, in addition to the 1 server node"
  type        = number
  default     = 0
}

variable "namespace" {
  description = "Kubernetes namespace Keycloak is deployed into"
  type        = string
  default     = "keycloak"
}

variable "keycloak_hostname" {
  description = "Hostname used for the Keycloak ingress + TLS certificate"
  type        = string
  default     = "keycloak.local"
}

variable "keycloak_admin_user" {
  description = "Keycloak bootstrap admin username"
  type        = string
  default     = "admin"
}

variable "keycloak_chart_version" {
  description = "Pinned Bitnami Keycloak Helm chart version, for reproducible deploys"
  type        = string
  default     = "25.2.0"
}

variable "https_node_port" {
  description = "Host port mapped to the k3d built-in loadbalancer's 443"
  type        = number
  default     = 443
}

variable "enable_letsencrypt" {
  description = "If true, install cert-manager and issue a real Let's Encrypt certificate via HTTP-01 instead of using a self-signed one. Requires acme_email to be set, port 80 reachable from the public internet, and the EC2 Security Group opened accordingly (not managed by this Terraform config)."
  type        = bool
  default     = false
}

variable "acme_email" {
  description = "Real, reachable email address for Let's Encrypt account registration and certificate-expiry notices. Required when enable_letsencrypt = true."
  type        = string
  default     = ""

  validation {
    condition     = !var.enable_letsencrypt || length(var.acme_email) > 3
    error_message = "acme_email must be set to a real email address when enable_letsencrypt = true."
  }
}

variable "cert_manager_chart_version" {
  description = "Pinned jetstack/cert-manager Helm chart version. Verify it still exists with: helm search repo jetstack/cert-manager --versions"
  type        = string
  default     = "v1.18.2"
}
