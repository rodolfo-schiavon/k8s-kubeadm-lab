output "project_id" {
  value = digitalocean_project.main.id
}

output "vpc_ip_range" {
  value = data.digitalocean_vpc.main.ip_range
}

output "control_plane_public_ip" {
  value = digitalocean_droplet.nodes["control_plane"].ipv4_address
}

output "ingress_public_ip" {
  description = "Reserved IP or control-plane public IP for Ingress/DNS/API endpoint"
  value       = local.ingress_public_ip
}

output "control_plane_private_ip" {
  value = digitalocean_droplet.nodes["control_plane"].ipv4_address_private
}

output "worker_app_public_ip" {
  value = digitalocean_droplet.nodes["worker_app"].ipv4_address
}

output "worker_app_private_ip" {
  value = digitalocean_droplet.nodes["worker_app"].ipv4_address_private
}

output "worker_data_public_ip" {
  value = digitalocean_droplet.nodes["worker_data"].ipv4_address
}

output "worker_data_private_ip" {
  value = digitalocean_droplet.nodes["worker_data"].ipv4_address_private
}

output "all_nodes" {
  value = {
    for k, d in digitalocean_droplet.nodes : k => {
      name       = d.name
      public_ip  = d.ipv4_address
      private_ip = d.ipv4_address_private
      node_role  = local.droplet_configs[k].node_role
      hostname   = local.droplet_configs[k].hostname
    }
  }
}

output "suggested_dns" {
  value = {
    wildcard  = "*.${var.domain_name} -> ${local.ingress_public_ip}"
    app       = "app.${var.domain_name}"
    api       = "api.${var.domain_name}"
    argocd    = "argocd.${var.domain_name}"
    dashboard = "dashboard.${var.domain_name}"
    target_ip = local.ingress_public_ip
  }
}

output "ssh_commands" {
  value = {
    for k, d in digitalocean_droplet.nodes : k => "ssh root@${d.ipv4_address}  # ${local.droplet_configs[k].hostname}"
  }
}

output "kubeadm_bootstrap_hints" {
  value = <<-EOT
    1. ./scripts/bootstrap-cluster.sh
    2. ./scripts/install-argocd.sh
    3. Configure DNS: *.${var.domain_name} -> ${local.ingress_public_ip}
  EOT
}
