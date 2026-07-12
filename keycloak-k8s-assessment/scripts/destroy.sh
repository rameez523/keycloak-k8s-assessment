#!/usr/bin/env bash
#
# scripts/destroy.sh
# Tears down everything: Keycloak, the namespace, and the k3d cluster
# itself (including its Docker containers/volumes).
#
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TF_DIR="${ROOT_DIR}/terraform"

cd "$TF_DIR"

echo "==> terraform destroy"
terraform destroy -auto-approve

echo "==> Done. Verifying no leftover k3d cluster..."
k3d cluster list || true
