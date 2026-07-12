#!/usr/bin/env bash
#
# scripts/get-credentials.sh
# Prints the Keycloak URL, admin username, and admin password.
#
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TF_DIR="${ROOT_DIR}/terraform"

cd "$TF_DIR"

echo "Keycloak URL:      $(terraform output -raw keycloak_url)"
echo "Admin username:    $(terraform output -raw keycloak_admin_user)"
echo "Admin password:    $(terraform output -raw keycloak_admin_password)"
echo ""
echo "(Equivalent kubectl command, if you'd rather pull it straight from"
echo " the cluster instead of Terraform state:)"
echo "  kubectl --kubeconfig ${TF_DIR}/.kube/config -n keycloak get secret keycloak \\"
echo "    -o jsonpath='{.data.admin-password}' | base64 -d; echo"
