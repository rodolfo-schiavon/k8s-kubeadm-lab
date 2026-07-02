#!/usr/bin/env bash
# install-control-plane.sh — kubeadm init + Calico CNI
# https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/create-cluster-kubeadm/
set -euo pipefail

CONTROL_PLANE_ENDPOINT="${CONTROL_PLANE_ENDPOINT:?required}"
PRIVATE_IP="${PRIVATE_IP:?required}"
PUBLIC_IP="${PUBLIC_IP:-}"
RESERVED_IP="${RESERVED_IP:-$CONTROL_PLANE_ENDPOINT}"
K8S_VERSION="${K8S_VERSION:-1.31}"
POD_CIDR="${POD_CIDR:-192.168.0.0/16}"
CALICO_VERSION="${CALICO_VERSION:-v3.28.2}"

if [[ -f /etc/kubernetes/admin.conf ]]; then
  echo "Cluster already initialized, skipping kubeadm init."
else
  cat >/tmp/kubeadm-config.yaml <<EOF
apiVersion: kubeadm.k8s.io/v1beta4
kind: InitConfiguration
localAPIEndpoint:
  advertiseAddress: ${PRIVATE_IP}
nodeRegistration:
  kubeletExtraArgs:
    - name: node-ip
      value: "${PRIVATE_IP}"
  name: k8s-lab-control-plane
---
apiVersion: kubeadm.k8s.io/v1beta4
kind: ClusterConfiguration
kubernetesVersion: v${K8S_VERSION}.14
controlPlaneEndpoint: ${CONTROL_PLANE_ENDPOINT}:6443
networking:
  podSubnet: ${POD_CIDR}
apiServer:
  certSANs:
    - ${RESERVED_IP}
    - ${PRIVATE_IP}
$( [[ -n "$PUBLIC_IP" ]] && echo "    - ${PUBLIC_IP}" )
EOF

  kubeadm init --config /tmp/kubeadm-config.yaml --upload-certs | tee /tmp/kubeadm-init.log

  mkdir -p "$HOME/.kube"
  cp /etc/kubernetes/admin.conf "$HOME/.kube/config"
  chown "$(id -u)":"$(id -g)" "$HOME/.kube/config"
fi

export KUBECONFIG=/etc/kubernetes/admin.conf

echo "==> Installing Calico CNI ${CALICO_VERSION}..."
curl -fsSL "https://raw.githubusercontent.com/projectcalico/calico/${CALICO_VERSION}/manifests/calico.yaml" -o /tmp/calico.yaml
sed -i 's|# - name: CALICO_IPV4POOL_CIDR|- name: CALICO_IPV4POOL_CIDR|' /tmp/calico.yaml
sed -i 's|#   value: "192.168.0.0/16"|  value: "'"${POD_CIDR}"'"|' /tmp/calico.yaml
kubectl apply -f /tmp/calico.yaml

echo "==> Waiting for control plane..."
kubectl wait --for=condition=Ready node/k8s-lab-control-plane --timeout=300s 2>/dev/null || true
kubectl get nodes -o wide

echo "==> Saving join command..."
kubeadm token create --print-join-command >/tmp/kubeadm-join.sh
chmod +x /tmp/kubeadm-join.sh
cat /tmp/kubeadm-join.sh

echo "CONTROL_PLANE_READY=1"
