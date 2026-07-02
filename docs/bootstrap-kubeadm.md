# Bootstrap do cluster kubeadm

Seguir documentação oficial:

1. [Installing kubeadm](https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/install-kubeadm/)
2. [Creating a cluster with kubeadm](https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/create-cluster-kubeadm/)

## Automatizado

```bash
./scripts/create-digitalocean-infra.sh --yes
./scripts/bootstrap-cluster.sh --yes
./scripts/install-argocd.sh
```

## Troubleshooting

- **kubelet crashloop antes do init:** esperado até `kubeadm init`.
- **Workers não joinam:** verifique firewall 6443 na VPC e `--control-plane-endpoint`.
- **Calico não sobe:** confirme `podSubnet: 192.168.0.0/16`.
