variable "do_token" {
  description = "DigitalOcean API token"
  type        = string
  sensitive   = true
}

variable "project_name" {
  description = "Name of the DigitalOcean project and resource prefix"
  type        = string
  default     = "k8s-kubeadm-lab"
}

variable "environment" {
  description = "Environment label (lab, dev, prod)"
  type        = string
  default     = "lab"
}

variable "region" {
  description = "DigitalOcean region (e.g. nyc3)"
  type        = string
  default     = "nyc3"
}

variable "droplet_image" {
  description = "Droplet image slug"
  type        = string
  default     = "ubuntu-24-04-x64"
}

variable "droplet_size" {
  description = "Default droplet size for worker nodes"
  type        = string
  default     = "s-2vcpu-4gb"
}

variable "control_plane_size" {
  description = "Droplet size for control-plane"
  type        = string
  default     = "s-2vcpu-4gb"
}

variable "ssh_key_name" {
  description = "Name of SSH key registered in DigitalOcean"
  type        = string
}

variable "domain_name" {
  description = "Base domain for suggested DNS records"
  type        = string
  default     = "k8s-lab.zerotouch.tec.br"
}

variable "allowed_ssh_cidr" {
  description = "CIDR allowed for SSH (e.g. YOUR_IP/32)"
  type        = string
}

variable "assign_ingress_reserved_ip" {
  description = "Assign Reserved IP to control-plane for stable ingress/API endpoint"
  type        = bool
  default     = true
}

variable "tags" {
  description = "Additional tags for resources"
  type        = list(string)
  default     = ["k8s-lab", "kubeadm"]
}
