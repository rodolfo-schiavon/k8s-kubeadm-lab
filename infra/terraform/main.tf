locals {
  name_prefix = "${var.project_name}-${var.environment}"

  droplet_size_for = {
    control_plane = var.control_plane_size
    worker_app    = var.droplet_size
    worker_data   = var.droplet_size
  }

  droplet_configs = {
    control_plane = {
      hostname  = "k8s-lab-control-plane"
      node_role = "control-plane"
    }
    worker_app = {
      hostname  = "k8s-lab-worker-app"
      node_role = "worker-app"
    }
    worker_data = {
      hostname  = "k8s-lab-worker-data"
      node_role = "worker-data"
    }
  }

  common_tags = concat(var.tags, [var.environment, var.project_name])
}

data "digitalocean_ssh_key" "main" {
  name = var.ssh_key_name
}

data "digitalocean_vpc" "main" {
  name = "default-${var.region}"
}

resource "digitalocean_project" "main" {
  name        = var.project_name
  description = "Kubernetes kubeadm lab - ${var.environment}"
  purpose     = "Web Application"
  environment = "Development"
}

resource "digitalocean_firewall" "k8s" {
  name = "${local.name_prefix}-fw"

  droplet_ids = [for k, d in digitalocean_droplet.nodes : d.id]

  inbound_rule {
    protocol         = "tcp"
    port_range       = "22"
    source_addresses = [var.allowed_ssh_cidr]
  }

  inbound_rule {
    protocol         = "tcp"
    port_range       = "80"
    source_addresses = ["0.0.0.0/0", "::/0"]
  }

  inbound_rule {
    protocol         = "tcp"
    port_range       = "443"
    source_addresses = ["0.0.0.0/0", "::/0"]
  }

  inbound_rule {
    protocol         = "tcp"
    port_range       = "30080"
    source_addresses = ["0.0.0.0/0", "::/0"]
  }

  inbound_rule {
    protocol         = "tcp"
    port_range       = "30443"
    source_addresses = ["0.0.0.0/0", "::/0"]
  }

  inbound_rule {
    protocol         = "tcp"
    port_range       = "6443"
    source_addresses = [data.digitalocean_vpc.main.ip_range]
  }

  inbound_rule {
    protocol    = "tcp"
    port_range  = "6443"
    source_tags = ["k8s-kubeadm-lab"]
  }

  inbound_rule {
    protocol         = "tcp"
    port_range       = "6443"
    source_addresses = [var.allowed_ssh_cidr]
  }

  inbound_rule {
    protocol         = "tcp"
    port_range       = "10250"
    source_addresses = [data.digitalocean_vpc.main.ip_range]
  }

  # Calico VXLAN
  inbound_rule {
    protocol         = "udp"
    port_range       = "4789"
    source_addresses = [data.digitalocean_vpc.main.ip_range]
  }

  # Calico BGP (optional)
  inbound_rule {
    protocol         = "tcp"
    port_range       = "179"
    source_addresses = [data.digitalocean_vpc.main.ip_range]
  }

  outbound_rule {
    protocol              = "tcp"
    port_range            = "1-65535"
    destination_addresses = ["0.0.0.0/0", "::/0"]
  }

  outbound_rule {
    protocol              = "udp"
    port_range            = "1-65535"
    destination_addresses = ["0.0.0.0/0", "::/0"]
  }

  outbound_rule {
    protocol              = "icmp"
    destination_addresses = ["0.0.0.0/0", "::/0"]
  }
}

resource "digitalocean_droplet" "nodes" {
  for_each = local.droplet_configs

  name     = "${local.name_prefix}-${each.value.hostname}"
  region   = var.region
  image    = var.droplet_image
  size     = local.droplet_size_for[each.key]
  vpc_uuid = data.digitalocean_vpc.main.id
  ssh_keys = [data.digitalocean_ssh_key.main.id]
  tags     = concat(local.common_tags, [each.value.node_role, each.value.hostname])

  user_data = <<-EOF
    #!/bin/bash
    set -euo pipefail
    hostnamectl set-hostname ${each.value.hostname}
    echo "NODE_ROLE=${each.value.node_role}" >> /etc/environment
    echo "LAB_ENV=${var.environment}" >> /etc/environment
  EOF
}

resource "digitalocean_project_resources" "main" {
  project = digitalocean_project.main.id
  resources = [
    for k, d in digitalocean_droplet.nodes : d.urn
  ]
}
