############################################
# providers.tf
############################################

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    null = {
      source  = "hashicorp/null"
      version = "~> 3.2"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.4"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.31"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.14"
    }
    time = {
      source  = "hashicorp/time"
      version = "~> 0.11"
    }
  }
}

# The kubeconfig file below is written by the k3d cluster-creation step in
# cluster.tf (via `k3d kubeconfig write`), to ./terraform/.kube/config.
# Terraform resolves provider configuration lazily, so this works as long
# as the cluster resource is created before anything that uses these
# providers -- which is why deploy.sh applies with -target on the cluster
# first. See README.md ("Why a two-phase apply?") for details.

provider "kubernetes" {
  config_path = "${path.module}/.kube/config"
}

provider "helm" {
  kubernetes {
    config_path = "${path.module}/.kube/config"
  }
}
