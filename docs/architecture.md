# Arquitetura

3 nós DigitalOcean (nyc3), cluster kubeadm single control-plane, CNI Calico, GitOps Argo CD.

## Componentes

| Camada | Tecnologia |
|--------|------------|
| Infra | Terraform + DO Firewall + Reserved IP |
| Cluster | kubeadm, containerd, Calico |
| Ingress | Traefik (hostNetwork no CP) |
| TLS | cert-manager + Let's Encrypt |
| GitOps | Argo CD |
| UI | Kubernetes Dashboard, Argo CD UI |
| App | Next.js, FastAPI, Bitnami PostgreSQL |
| Storage | local-path-provisioner |

## Fluxo GitOps

Push → GitHub Actions (build GHCR) → values.yaml → Argo CD sync → cluster.
