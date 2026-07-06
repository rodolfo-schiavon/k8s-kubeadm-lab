# Runbook

## Lab Lifecycle (GitHub Actions)

Destruir ou recriar o ambiente para **custo zero** quando o lab não estiver em uso.

### Pré-requisitos (uma vez)

1. **Spaces backend** — siga [`infra/bootstrap/spaces/README.md`](../infra/bootstrap/spaces/README.md)
2. **Secrets no GitHub** (Settings → Secrets and variables → Actions):

| Secret | Descrição |
|--------|-----------|
| `DO_TOKEN` | Token API DigitalOcean |
| `SSH_PRIVATE_KEY` | Chave privada SSH (par da `ssh_key_name` no Terraform) |
| `TF_BACKEND_BUCKET` | Bucket Spaces |
| `TF_BACKEND_REGION` | ex. `nyc3` |
| `TF_BACKEND_ACCESS_KEY` | Spaces access key |
| `TF_BACKEND_SECRET_KEY` | Spaces secret key |

3. **Environment** `lab-production` (opcional) — adicione required reviewers para `destroy`/`recreate`

### Disparar workflow

**Actions → Lab Lifecycle → Run workflow**

| Ação | Uso | Confirmação |
|------|-----|-------------|
| `destroy` | Remove droplets + reserved IP (**$0/mês**) | `confirm` = `DESTROY` |
| `provision` | Cria infra + cluster + apps | — |
| `recreate` | destroy + provision completo | `confirm` = `DESTROY` |

Após `provision`/`recreate`, o **Step Summary** exibe:
- `worker_app_public_ip` — atualize DNS manualmente
- Senha Argo CD e token Dashboard

### DNS manual (após cada provision)

Aponte estes registros **A** para o `worker_app_public_ip` do summary:

- `app.k8s-lab.zerotouch.tec.br`
- `api.k8s-lab.zerotouch.tec.br`
- `argocd.k8s-lab.zerotouch.tec.br`
- `dashboard.k8s-lab.zerotouch.tec.br`

### Local (alternativa)

```bash
export TF_VAR_do_token="..."
export TF_BACKEND_BUCKET="..." TF_BACKEND_REGION="..." \
  TF_BACKEND_ACCESS_KEY="..." TF_BACKEND_SECRET_KEY="..."
export SSH_PRIVATE_KEY="$(cat ~/.ssh/id_rsa)"  # ou use ssh-agent

./scripts/lab-lifecycle.sh destroy    # custo zero
./scripts/lab-lifecycle.sh provision  # ~$72/mês
./scripts/lab-lifecycle.sh recreate   # destroy + provision
```

### Custos

| Estado | Custo mensal aprox. |
|--------|---------------------|
| Lab ligado (3× s-2vcpu-4gb) | ~$72 |
| Destruído (sem droplets/reserved IP) | **$0** |

---

## URLs do lab (após DNS)

| Serviço | URL |
|---------|-----|
| App demo | http://app.k8s-lab.zerotouch.tec.br |
| API | http://api.k8s-lab.zerotouch.tec.br |
| Argo CD | http://argocd.k8s-lab.zerotouch.tec.br |
| Dashboard | http://dashboard.k8s-lab.zerotouch.tec.br |

HTTPS depende do cert-manager (TLS secrets).

## Senha Argo CD

```bash
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d
```

## Token Dashboard

```bash
kubectl create sa dashboard-admin -n kubernetes-dashboard --dry-run=client -o yaml | kubectl apply -f -
kubectl create clusterrolebinding dashboard-admin \
  --clusterrole=cluster-admin \
  --serviceaccount=kubernetes-dashboard:dashboard-admin \
  --dry-run=client -o yaml | kubectl apply -f -
kubectl -n kubernetes-dashboard create token dashboard-admin
```

## Upgrade kubeadm

https://kubernetes.io/docs/tasks/administer-cluster/kubeadm/kubeadm-upgrade/

## Backup etcd

https://kubernetes.io/docs/tasks/administer-cluster/configure-upgrade-etcd/backing-up-etcd/

## Renovar certificados

https://kubernetes.io/docs/tasks/administer-cluster/kubeadm/kubeadm-certs/
