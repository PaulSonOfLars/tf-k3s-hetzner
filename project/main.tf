terraform {
  required_providers {
    hcloud = {
      source  = "hetznercloud/hcloud"
      version = "1.31.1"
    }
  }
}

# Configure the Hetzner Cloud Provider
# Uses the HCLOUD_TOKEN env variable
provider "hcloud" {}
