#!/usr/bin/env bash
# ensure-calico-vxlan.sh — DO firewall blocks IPIP; Calico must use VXLAN
set -euo pipefail

KUBECONFIG="${KUBECONFIG:?KUBECONFIG required}"
export KUBECONFIG

echo "==> Ensuring Calico VXLAN mode..."
kubectl wait --for=condition=Established crd/ippools.crd.projectcalico.org --timeout=120s

current="$(kubectl get ippool default-ipv4-ippool -o jsonpath='{.spec.vxlanMode}' 2>/dev/null || echo "")"
if [[ "$current" != "Always" ]]; then
  kubectl patch ippool default-ipv4-ippool --type merge \
    -p '{"spec":{"ipipMode":"Never","vxlanMode":"Always"}}'
  kubectl rollout restart daemonset/calico-node -n kube-system
  kubectl rollout status daemonset/calico-node -n kube-system --timeout=180s
  sleep 10
fi

vxlan="$(kubectl get ippool default-ipv4-ippool -o jsonpath='{.spec.vxlanMode}')"
ipip="$(kubectl get ippool default-ipv4-ippool -o jsonpath='{.spec.ipipMode}')"
echo "Calico ippool: vxlanMode=${vxlan} ipipMode=${ipip}"
if [[ "$vxlan" != "Always" ]]; then
  echo "ERROR: Calico VXLAN not active" >&2
  exit 1
fi
