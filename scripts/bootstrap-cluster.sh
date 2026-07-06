#!/usr/bin/env bash
# bootstrap-cluster.sh — Orchestrate kubeadm cluster bootstrap
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TF_DIR="${SCRIPT_DIR}/../infra/terraform"
INFRA_SCRIPTS="${SCRIPT_DIR}/../infra/scripts"
K8S_VERSION="${K8S_VERSION:-1.31}"
AUTO_YES=false
SSH_OPTS="${SSH_OPTS:--o StrictHostKeyChecking=no -o ConnectTimeout=30}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --yes|-y) AUTO_YES=true; shift ;;
    -h|--help)
      echo "Uso: bootstrap-cluster.sh [--yes]"
      exit 0
      ;;
    *) echo "Opção desconhecida: $1" >&2; exit 1 ;;
  esac
done

cd "$TF_DIR"
if ! terraform output -json all_nodes &>/dev/null; then
  echo "ERROR: Run terraform apply first."
  exit 1
fi

CP_IP=$(terraform output -raw control_plane_public_ip)
CP_PRIVATE=$(terraform output -raw control_plane_private_ip)
INGRESS_IP=$(terraform output -raw ingress_public_ip)
W_APP_IP=$(terraform output -raw worker_app_public_ip)
W_APP_PRIVATE=$(terraform output -raw worker_app_private_ip)
W_DATA_IP=$(terraform output -raw worker_data_public_ip)
W_DATA_PRIVATE=$(terraform output -raw worker_data_private_ip)

echo "=== kubeadm Cluster Bootstrap ==="
echo "Control plane: $CP_IP (private $CP_PRIVATE)"
echo "Ingress/API:   $INGRESS_IP"
echo "Worker app:    $W_APP_IP"
echo "Worker data:   $W_DATA_IP"
echo

if [[ "$AUTO_YES" != true ]]; then
  read -r -p "Proceed? [y/N] " ans
  [[ "${ans,,}" == "y" ]] || exit 0
fi

wait_ssh() {
  local ip=$1
  local i
  for i in $(seq 1 60); do
    if ssh $SSH_OPTS "root@${ip}" "echo ok" &>/dev/null; then break; fi
    sleep 10
  done
  if ! ssh $SSH_OPTS "root@${ip}" "echo ok" &>/dev/null; then
    echo "SSH timeout: $ip" >&2
    return 1
  fi
  echo "==> Waiting for cloud-init on $ip..."
  ssh $SSH_OPTS "root@${ip}" bash -s <<'REMOTE'
set -euo pipefail
if command -v cloud-init >/dev/null 2>&1; then
  cloud-init status --wait 2>/dev/null || true
fi
waited=0
while fuser /var/lib/dpkg/lock-frontend >/dev/null 2>&1 \
  || fuser /var/lib/apt/lists/lock >/dev/null 2>&1; do
  echo "apt lock held, waiting..."
  sleep 5
  waited=$((waited + 5))
  if [[ "$waited" -ge 600 ]]; then exit 1; fi
done
REMOTE
}

bootstrap_node() {
  local ip=$1
  echo "==> Preparing node $ip..."
  wait_ssh "$ip"
  scp $SSH_OPTS -q "${INFRA_SCRIPTS}/bootstrap-node.sh" "root@${ip}:/tmp/"
  ssh $SSH_OPTS "root@${ip}" "export K8S_VERSION='${K8S_VERSION}'; bash /tmp/bootstrap-node.sh"
}

for ip in "$CP_IP" "$W_APP_IP" "$W_DATA_IP"; do
  bootstrap_node "$ip"
done

echo "==> Initializing control plane..."
scp $SSH_OPTS -q "${INFRA_SCRIPTS}/install-control-plane.sh" "root@${CP_IP}:/tmp/"
ssh $SSH_OPTS "root@${CP_IP}" \
  "export CONTROL_PLANE_ENDPOINT='${INGRESS_IP}' PRIVATE_IP='${CP_PRIVATE}' PUBLIC_IP='${CP_IP}' RESERVED_IP='${INGRESS_IP}' K8S_VERSION='${K8S_VERSION}'; bash /tmp/install-control-plane.sh" \
  | tee /tmp/kubeadm-cp-install.log

JOIN_CMD=$(ssh $SSH_OPTS "root@${CP_IP}" "kubeadm token create --print-join-command 2>/dev/null | head -1")
# Workers join via VPC private IP (firewall blocks 6443 on public/reserved IP)
JOIN_CMD="${JOIN_CMD//${INGRESS_IP}/${CP_PRIVATE}}"
if [[ -z "$JOIN_CMD" ]]; then
  JOIN_CMD=$(ssh $SSH_OPTS "root@${CP_IP}" "cat /tmp/kubeadm-join.sh 2>/dev/null | head -1")
  JOIN_CMD="${JOIN_CMD//${INGRESS_IP}/${CP_PRIVATE}}"
fi

join_worker() {
  local ip=$1 name=$2 role=$3 private_ip=$4
  echo "==> Joining $name ($ip)..."
  scp $SSH_OPTS -q "${INFRA_SCRIPTS}/install-worker.sh" "root@${ip}:/tmp/"
  ssh $SSH_OPTS "root@${ip}" \
    "export NODE_NAME='${name}' NODE_ROLE='${role}' PRIVATE_IP='${private_ip}' JOIN_CMD='${JOIN_CMD}'; bash /tmp/install-worker.sh"
}

join_worker "$W_APP_IP" "k8s-lab-worker-app" "worker-app" "$W_APP_PRIVATE"
join_worker "$W_DATA_IP" "k8s-lab-worker-data" "worker-data" "$W_DATA_PRIVATE"

echo "==> Labeling nodes..."
ssh $SSH_OPTS "root@${CP_IP}" bash -s <<'REMOTE'
export KUBECONFIG=/etc/kubernetes/admin.conf
kubectl label node k8s-lab-control-plane node-role=control-plane --overwrite
kubectl label node k8s-lab-worker-app node-role=worker-app --overwrite
kubectl label node k8s-lab-worker-data node-role=worker-data --overwrite
kubectl get nodes -o wide
REMOTE

echo "==> Installing local-path-provisioner..."
ssh $SSH_OPTS "root@${CP_IP}" bash -s <<'REMOTE'
export KUBECONFIG=/etc/kubernetes/admin.conf
kubectl apply -f https://raw.githubusercontent.com/rancher/local-path-provisioner/v0.0.30/deploy/local-path-storage.yaml
kubectl patch storageclass local-path -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}' 2>/dev/null || true
REMOTE

echo "==> Fetching kubeconfig..."
scp $SSH_OPTS -q "root@${CP_IP}:/etc/kubernetes/admin.conf" "${SCRIPT_DIR}/../kubeconfig"
sed -i "s|server: https://.*:6443|server: https://${INGRESS_IP}:6443|" "${SCRIPT_DIR}/../kubeconfig" 2>/dev/null || \
  sed -i '' "s|server: https://.*:6443|server: https://${INGRESS_IP}:6443|" "${SCRIPT_DIR}/../kubeconfig"

export KUBECONFIG="${SCRIPT_DIR}/../kubeconfig"
if command -v kubectl &>/dev/null; then
  kubectl get nodes -o wide
fi

echo "Bootstrap complete. KUBECONFIG=${SCRIPT_DIR}/../kubeconfig"
