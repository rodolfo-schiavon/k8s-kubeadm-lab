output "bucket_name" {
  value = digitalocean_spaces_bucket.tfstate.name
}

output "bucket_endpoint" {
  value = "https://${var.region}.digitaloceanspaces.com"
}

output "state_key" {
  value = "k8s-kubeadm-lab/terraform.tfstate"
}

output "github_secrets_hint" {
  value = <<-EOT
    Configure these GitHub repository secrets:
      TF_BACKEND_BUCKET       = ${digitalocean_spaces_bucket.tfstate.name}
      TF_BACKEND_REGION       = ${var.region}
      TF_BACKEND_ACCESS_KEY   = (create in DO Control Panel → API → Spaces Keys)
      TF_BACKEND_SECRET_KEY   = (create in DO Control Panel → API → Spaces Keys)
  EOT
}
