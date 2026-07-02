# Runbook

## Upgrade kubeadm

https://kubernetes.io/docs/tasks/administer-cluster/kubeadm/kubeadm-upgrade/

## Backup etcd

https://kubernetes.io/docs/tasks/administer-cluster/configure-upgrade-etcd/backing-up-etcd/

## Renovar certificados

https://kubernetes.io/docs/tasks/administer-cluster/kubeadm/kubeadm-certs/

## Destruir lab

```bash
cd infra/terraform
terraform destroy
```

## Senha Argo CD

```bash
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d
```

## Token Dashboard

```bash
kubectl -n kubernetes-dashboard create token admin-user 2>/dev/null || \
kubectl create sa dashboard-admin -n kubernetes-dashboard && \
kubectl create clusterrolebinding dashboard-admin --clusterrole=cluster-admin --serviceaccount=kubernetes-dashboard:dashboard-admin
kubectl -n kubernetes-dashboard create token dashboard-admin
```
