############################################
# cluster.tf
############################################

resource "null_resource" "k3d_cluster" {
  triggers = {
    cluster_name       = var.cluster_name
    agents             = var.k3d_agents
    https_port         = var.https_node_port
    enable_letsencrypt = var.enable_letsencrypt
  }

  provisioner "local-exec" {
    command = <<-EOT
      set -euo pipefail

      if k3d cluster list "${var.cluster_name}" &>/dev/null; then
        echo "Cluster '${var.cluster_name}' already exists, skipping create."
      else
        k3d cluster create "${var.cluster_name}" \
          --agents ${var.k3d_agents} \
          --port "${var.https_node_port}:443@loadbalancer" \
          %{ if var.enable_letsencrypt ~}
          --port "80:80@loadbalancer" \
          %{ endif ~}
          --api-port 6550 \
          --k3s-arg "--disable=metrics-server@server:0" \
          --wait --timeout 300s
      fi

      mkdir -p "${path.module}/.kube"
      k3d kubeconfig write "${var.cluster_name}" --output "${path.module}/.kube/config"
      chmod 600 "${path.module}/.kube/config"
    EOT
  }

  provisioner "local-exec" {
    when    = destroy
    command = "k3d cluster delete ${self.triggers.cluster_name} || true"
  }
}

resource "time_sleep" "wait_for_traefik" {
  create_duration = "20s"
  depends_on      = [null_resource.k3d_cluster]
}
