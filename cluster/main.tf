terraform {
  required_providers {
    kustomization = {
      source  = "kbst/kustomization"
      version = "0.5.0"
    }
    kubernetes = {
      source = "hashicorp/kubernetes"
      version = "2.5.0"
    }
  }
}

provider "kustomization" {
  kubeconfig_path = "../project/certificate.txt"
}


provider "kubernetes" {
  experiments {
    manifest_resource = true
  }

  config_path = "../project/certificate.txt"
}



