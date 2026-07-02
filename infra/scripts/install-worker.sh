#!/usr/bin/env bash
# install-worker.sh — kubeadm join worker node
set -euo pipefail

NODE_NAME="${NODE_NAME:?required}"
NODE_ROLE="${NODE_ROLE:?required}"
PRIVATE_IP="${PRIVATE_IP:?required}"
JOIN_CMD="${JOIN_CMD:?required}"

# shellcheck disable=SC2086
$JOIN_CMD --node-name "$NODE_NAME" \
  --cri-socket unix:///var/run/containerd/containerd.sock

# Force kubelet to register VPC private IP (DO eth1), not anchor IP on eth0
if [[ -n "${PRIVATE_IP:-}" ]]; then
  sed -i "s|KUBELET_KUBEADM_ARGS=\"|KUBELET_KUBEADM_ARGS=\"--node-ip=${PRIVATE_IP} |" /var/lib/kubelet/kubeadm-flags.env
  systemctl restart kubelet
fi

# Label from control plane after join — done in bootstrap-cluster.sh
echo "WORKER_JOINED=1 NODE_NAME=${NODE_NAME} NODE_ROLE=${NODE_ROLE}"
