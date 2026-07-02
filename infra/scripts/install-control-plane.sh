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
kubernetesVersion: v${K8S_VERSION}.0
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
kubectl apply -f "https://raw.githubusercontent.com/projectcalico/calico/${CALICO_VERSION}/manifests/tigera-operator.yaml"

cat >/tmp/calico-custom-resources.yaml <<EOF
apiVersion: operator.tigera.io/v1
kind: Installation
metadata:
  name: default
spec:
  calicoNetwork:
    ipPools:
    - blockSize: 26
      cidr: ${POD_CIDR}
      encapsulation: VXLANCrossSubnet
      natOutgoing: Enabled
      nodeSelector: all()
---
apiVersion: operator.tigera.io/v1
kind: APIServer
metadata:
  name: default
spec: {}
EOF

kubectl create -f /tmp/calico-custom-resources.yaml 2>/dev/null || kubectl apply -f /tmp/calico-custom-resources.yaml

echo "==> Waiting for control plane..."
kubectl wait --for=condition=Ready node/k8s-lab-control-plane --timeout=300s 2>/dev/null || true
kubectl get nodes -o wide

echo "==> Saving join command..."
kubeadm token create --print-join-command >/tmp/kubeadm-join.sh
chmod +x /tmp/kubeadm-join.sh
cat /tmp/kubeadm-join.sh

echo "CONTROL_PLANE_READY=1"
