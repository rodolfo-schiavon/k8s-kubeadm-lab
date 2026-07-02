resource "digitalocean_reserved_ip" "ingress" {
  count  = var.assign_ingress_reserved_ip ? 1 : 0
  region = var.region
}

resource "digitalocean_reserved_ip_assignment" "control_plane" {
  count      = var.assign_ingress_reserved_ip ? 1 : 0
  ip_address = digitalocean_reserved_ip.ingress[0].ip_address
  droplet_id = digitalocean_droplet.nodes["control_plane"].id
}

locals {
  ingress_public_ip = var.assign_ingress_reserved_ip ? digitalocean_reserved_ip.ingress[0].ip_address : digitalocean_droplet.nodes["control_plane"].ipv4_address
}
