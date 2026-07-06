variable "do_token" {
  description = "DigitalOcean API token"
  type        = string
  sensitive   = true
}

variable "bucket_name" {
  description = "Globally unique Spaces bucket name for Terraform state"
  type        = string
  default     = "k8s-kubeadm-lab-tfstate"
}

variable "region" {
  description = "DigitalOcean region for Spaces (e.g. nyc3)"
  type        = string
  default     = "nyc3"
}
