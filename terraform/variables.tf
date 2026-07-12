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
  description = "Hostname used for the Keycloak ingress + TLS certificate (add to /etc/hosts -> 127.0.0.1)"
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
  default     = "24.0.7"
}

variable "https_node_port" {
  description = "Host port mapped to the k3d built-in loadbalancer's 443 (HTTPS only -- port 80 is intentionally NOT published for network hardening)"
  type        = number
  default     = 443
}
