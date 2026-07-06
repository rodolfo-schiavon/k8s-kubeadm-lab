terraform {
  required_version = ">= 1.5.0"

  backend "s3" {
    # Configured via -backend-config (see backend.hcl.example and GHA workflows)
  }

  required_providers {
    digitalocean = {
      source  = "digitalocean/digitalocean"
      version = "~> 2.40"
    }
  }
}

provider "digitalocean" {
  token = var.do_token
}
