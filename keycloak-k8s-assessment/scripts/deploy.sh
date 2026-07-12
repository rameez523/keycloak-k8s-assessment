#!/usr/bin/env bash
#
# scripts/deploy.sh
# One-shot, idempotent entry point: provisions the k3d cluster, then
# deploys Keycloak into it, entirely via Terraform.
#
# Usage:  ./scripts/deploy.sh
#
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TF_DIR="${ROOT_DIR}/terraform"

cd "$TF_DIR"

echo "==> terraform init"
terraform init -input=false

# --- Phase 1: create the local Kubernetes cluster -------------------------
# The kubernetes/helm providers in providers.tf read a kubeconfig file that
# does not exist until the k3d cluster is created. Terraform needs that
# file to be present the first time it tries to *use* those providers, so
# we bring the cluster up in its own apply first, then run the full apply
# for everything else. This is the standard workaround for the well-known
# "provider depends on a resource" chicken-and-egg problem when a single
# Terraform config both provisions a cluster and deploys into it.
echo "==> Phase 1/2: provisioning local Kubernetes cluster (k3d)"
terraform apply -auto-approve \
  -target=null_resource.k3d_cluster \
  -target=time_sleep.wait_for_traefik

# --- Phase 2: deploy Keycloak + supporting resources -----------------------
echo "==> Phase 2/2: deploying Keycloak, TLS, network policies"
terraform apply -auto-approve

echo ""
echo "==> Done. Summary:"
terraform output

HOSTNAME=$(terraform output -raw keycloak_admin_user >/dev/null 2>&1; terraform output -raw keycloak_url | sed -E 's#https://([^:/]+).*#\1#')

echo ""
echo "----------------------------------------------------------------------"
echo " If '${HOSTNAME}' does not resolve for you yet, add it to /etc/hosts:"
echo "   echo \"127.0.0.1 ${HOSTNAME}\" | sudo tee -a /etc/hosts"
echo ""
echo " Then open: $(terraform output -raw keycloak_url)"
echo " (your browser will warn about the self-signed cert -- that's"
echo "  expected for a local cluster; accept/continue.)"
echo ""
echo " Get admin credentials any time with: ./scripts/get-credentials.sh"
echo "----------------------------------------------------------------------"
