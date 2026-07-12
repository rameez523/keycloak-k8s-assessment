############################################
# outputs.tf
############################################

output "keycloak_url" {
  description = "HTTPS URL for the Keycloak admin console"
  value       = "https://${var.keycloak_hostname}:${var.https_node_port}/"
}

output "keycloak_admin_user" {
  description = "Keycloak admin username"
  value       = var.keycloak_admin_user
}

output "keycloak_admin_password" {
  description = "Keycloak admin password (also retrievable via scripts/get-credentials.sh)"
  value       = random_password.keycloak_admin.result
  sensitive   = true
}

output "kubeconfig_path" {
  description = "Path to the kubeconfig for this cluster"
  value       = "${path.module}/.kube/config"
}

output "cluster_name" {
  value = var.cluster_name
}

output "hosts_file_entry" {
  description = "Line to add to /etc/hosts so the ingress hostname resolves locally"
  value       = "127.0.0.1 ${var.keycloak_hostname}"
}
