# k8s-kubeadm-lab

Laboratório Kubernetes **production-grade** na DigitalOcean usando **kubeadm**, GitOps (Argo CD), Traefik Ingress, cert-manager e app demo 3 camadas (Next.js + FastAPI + PostgreSQL).

## Arquitetura

| Nó | Papel |
|----|-------|
| `k8s-lab-control-plane` | API server, etcd, Traefik, Argo CD, Dashboard |
| `k8s-lab-worker-app` | Frontend + Backend |
| `k8s-lab-worker-data` | PostgreSQL |

**Custo estimado:** ~$72/mês (3× `s-2vcpu-4gb`) + ~$4/mês Reserved IP.

## Referências oficiais Kubernetes

- [Installing kubeadm](https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/install-kubeadm/)
- [Creating a cluster with kubeadm](https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/create-cluster-kubeadm/)
- [Production environment](https://kubernetes.io/docs/setup/production-environment/)
- [Certificate management](https://kubernetes.io/docs/tasks/administer-cluster/kubeadm/kubeadm-certs/)

## Quick start

```bash
# 1. Infraestrutura
cp infra/terraform/terraform.tfvars.example infra/terraform/terraform.tfvars
# Edite terraform.tfvars (allowed_ssh_cidr, ssh_key_name)
export TF_VAR_do_token="$(doctl auth list -o json | jq -r '.[0].Contexts[0].AccessToken' 2>/dev/null || echo "$DO_TOKEN")"
./scripts/create-digitalocean-infra.sh

# 2. Bootstrap cluster kubeadm
./scripts/bootstrap-cluster.sh --yes

# 3. Argo CD + GitOps
./scripts/install-argocd.sh

# 4. Acesso
export KUBECONFIG="$(pwd)/kubeconfig"
kubectl get nodes
```

## Acesso rápido (sem DNS)

Após o bootstrap, use o IP do worker-app com NodePort Traefik:

```bash
export W_APP=$(cd infra/terraform && terraform output -raw worker_app_public_ip)
curl -H "Host: api.k8s-lab.zerotouch.tec.br" http://${W_APP}:30080/healthz
```

Ou port-forward local:

```bash
kubectl port-forward -n platform svc/demo-api 8080:80
curl http://127.0.0.1:8080/healthz
```

**Ingress IP reservado:** `terraform output ingress_public_ip` — aponte DNS ou mova Traefik para o control-plane com PSS privileged.

## URLs (após DNS ou /etc/hosts)

| Serviço | Host |
|---------|------|
| App demo | `https://app.<domain>` |
| API | `https://api.<domain>` |
| Argo CD | `https://argocd.<domain>` |
| Dashboard | `https://dashboard.<domain>` |

Aponte `*.k8s-lab.zerotouch.tec.br` para o `ingress_public_ip` do Terraform output, ou use `/etc/hosts`.

## Branches

- `main` — estado estável do lab
- `desenvolvimento` — integração contínua

## Destruir ambiente

```bash
cd infra/terraform && terraform destroy
```
