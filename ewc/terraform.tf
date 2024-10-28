terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.29.0"
    }

    helm = {
      source  = "hashicorp/helm"
      version = ">= 2.11.0"
    }

    rancher2 = {
      source  = "rancher/rancher2"
      version = "~> 4.1.0"
    }

    kubectl = {
      source  = "gavinbunney/kubectl"
      version = "1.14.0"
    }

    http = {
      source  = "hashicorp/http"
      version = "3.4.3"
    }

    external = {
      source  = "hashicorp/external"
      version = "2.3.3"
    }

    time = {
      source  = "hashicorp/time"
      version = "0.12.0"
    }

    vault = {
      source  = "hashicorp/vault"
      version = "4.4.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "3.6.3"
    }
  }

  required_version = "~> 1.3"
}
