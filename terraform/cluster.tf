############################################
# cluster.tf
# Provisions a local Kubernetes cluster (k3s-in-Docker via k3d).
#
# Why k3d instead of a "Rancher install"?
# The brief says "any distribution; Rancher preferred". Rancher itself is a
# multi-cluster *management UI* that you install ON TOP of an existing
# Kubernetes cluster (or provisions downstream clusters via RKE) -- it is
# not, by itself, a local single-node cluster distribution. For a fully
# scripted, reproducible, single-EC2-instance assessment environment, k3d
# (k3s running in Docker) is the standard lightweight equivalent used by
# Rancher's own RKE/k3s tooling, starts in ~30s, and is trivially automatable
# from Terraform via local-exec. See README "Design decisions" for the
# tradeoff discussion and how to swap in Rancher Desktop / RKE2 instead.
############################################

resource "null_resource" "k3d_cluster" {
  triggers = {
    cluster_name = var.cluster_name
    agents       = var.k3d_agents
    https_port   = var.https_node_port
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
          --api-port 6550 \
          --k3s-arg "--disable=metrics-server@server:0" \
          --wait --timeout 120s
      fi

      mkdir -p "${path.module}/.kube"
      k3d kubeconfig write "${var.cluster_name}" --output "${path.module}/.kube/config"
      chmod 600 "${path.module}/.kube/config"
    EOT
  }

  # Cluster teardown handled by destroy-time provisioner so
  # `terraform destroy` fully cleans up (no orphaned containers/volumes).
  provisioner "local-exec" {
    when    = destroy
    command = "k3d cluster delete ${self.triggers.cluster_name} || true"
  }
}

# Small delay resource: gives the k3d-managed Traefik ingress controller
# (deployed automatically by k3s) time to become Ready before Helm tries to
# create Ingress objects that depend on its IngressClass/admission webhook.
resource "time_sleep" "wait_for_traefik" {
  create_duration = "20s"
  depends_on      = [null_resource.k3d_cluster]
}
