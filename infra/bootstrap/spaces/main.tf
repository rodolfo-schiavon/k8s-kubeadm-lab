terraform {
  required_version = ">= 1.5.0"

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

resource "digitalocean_spaces_bucket" "tfstate" {
  name   = var.bucket_name
  region = var.region
}

resource "digitalocean_spaces_bucket_cors_configuration" "tfstate" {
  bucket = digitalocean_spaces_bucket.tfstate.name
  region = var.region

  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["GET", "PUT", "POST", "DELETE", "HEAD"]
    allowed_origins = ["*"]
    max_age_seconds = 3000
  }
}
