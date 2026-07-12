#!/usr/bin/env bash
#
# bootstrap.sh
# Installs the tooling this assignment needs on top of Terraform + git
# (which are assumed to already be present on the EC2 instance, per the
# assignment brief).
#
# Installs, only if missing:
#   - Docker            (container runtime k3d needs)
#   - kubectl           (Kubernetes CLI)
#   - k3d               (runs a real k3s Kubernetes cluster inside Docker)
#   - helm              (used indirectly by Terraform's helm provider, and
#                         handy for manual debugging)
#
# Tested on Ubuntu 22.04 / 24.04 EC2 AMIs. Re-run safely (idempotent).

set -euo pipefail

log() { printf '\n\033[1;32m==> %s\033[0m\n' "$1"; }

# ---------------------------------------------------------------------------
# 0. Basic sanity checks
# ---------------------------------------------------------------------------
if ! command -v terraform &>/dev/null; then
  echo "terraform not found on PATH. The assignment states Terraform is"
  echo "already installed on this instance -- please confirm/install it"
  echo "before continuing." >&2
  exit 1
fi

if ! command -v git &>/dev/null; then
  echo "git not found on PATH. Please install git before continuing." >&2
  exit 1
fi

# ---------------------------------------------------------------------------
# 1. Docker
# ---------------------------------------------------------------------------
if ! command -v docker &>/dev/null; then
  log "Installing Docker Engine"

  OS_ID=""
  OS_VERSION_ID=""
  if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS_ID="${ID:-}"
    OS_VERSION_ID="${VERSION_ID:-}"
  fi

  case "$OS_ID" in
    amzn)
      if [ "$OS_VERSION_ID" = "2" ]; then
        sudo amazon-linux-extras install docker -y
      else
        sudo dnf install -y docker
      fi
      sudo systemctl enable --now docker
      ;;
    ubuntu|debian)
      curl -fsSL https://get.docker.com | sudo sh
      ;;
    rhel|centos|rocky|almalinux|fedora)
      sudo dnf install -y dnf-plugins-core
      sudo dnf config-manager --add-repo https://download.docker.com/linux/${OS_ID}/docker-ce.repo || true
      sudo dnf install -y docker-ce docker-ce-cli containerd.io
      sudo systemctl enable --now docker
      ;;
    *)
      curl -fsSL https://get.docker.com | sudo sh
      ;;
  esac

  sudo usermod -aG docker "$USER"
  echo "Docker installed. You may need to log out/in (or run 'newgrp docker')"
  echo "for group membership to take effect before running deploy.sh."
else
  log "Docker already installed: $(docker --version)"
fi

# ---------------------------------------------------------------------------
# 2. kubectl
# ---------------------------------------------------------------------------
if ! command -v kubectl &>/dev/null; then
  log "Installing kubectl"
  KUBECTL_VERSION=$(curl -Ls https://dl.k8s.io/release/stable.txt)
  curl -LO "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl"
  chmod +x kubectl
  sudo mv kubectl /usr/local/bin/kubectl
else
  log "kubectl already installed: $(kubectl version --client --short 2>/dev/null || true)"
fi

# ---------------------------------------------------------------------------
# 3. k3d
# ---------------------------------------------------------------------------
if ! command -v k3d &>/dev/null; then
  log "Installing k3d"
  curl -s https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash
else
  log "k3d already installed: $(k3d version)"
fi

# ---------------------------------------------------------------------------
# 4. Helm
# ---------------------------------------------------------------------------
if ! command -v helm &>/dev/null; then
  log "Installing Helm"
  curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
else
  log "Helm already installed: $(helm version --short)"
fi

log "Bootstrap complete. Next: ./scripts/deploy.sh"
