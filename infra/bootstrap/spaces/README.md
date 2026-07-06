# Terraform remote state (DigitalOcean Spaces)

One-time bootstrap for the S3-compatible backend used by `infra/terraform` and GitHub Actions.

## 1. Create the bucket

```bash
cd infra/bootstrap/spaces
cp terraform.tfvars.example terraform.tfvars
export TF_VAR_do_token="YOUR_DO_TOKEN"
terraform init
terraform apply
```

## 2. Create Spaces access keys

In DigitalOcean: **API → Spaces access keys** → Generate new key.

## 3. Configure GitHub secrets

| Secret | Value |
|--------|-------|
| `TF_BACKEND_BUCKET` | output `bucket_name` |
| `TF_BACKEND_REGION` | e.g. `nyc3` |
| `TF_BACKEND_ACCESS_KEY` | Spaces access key |
| `TF_BACKEND_SECRET_KEY` | Spaces secret key |
| `SSH_PRIVATE_KEY` | private key matching `ssh_key_name` in Terraform |
| `DO_TOKEN` | DigitalOcean API token |

## 4. Local backend config (optional)

```bash
cd infra/terraform
cp backend.hcl.example backend.hcl
# edit backend.hcl
terraform init -backend-config=backend.hcl
```
