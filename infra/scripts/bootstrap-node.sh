#!/usr/bin/env bash
# bootstrap-node.sh — Prepare Ubuntu node for kubeadm (official prerequisites)
# https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/install-kubeadm/
set -euo pipefail

K8S_VERSION="${K8S_VERSION:-1.31}"

echo "==> [1/8] Disable swap..."
swapoff -a
sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab

echo "==> [2/8] Load kernel modules..."
cat >/etc/modules-load.d/k8s.conf <<EOF
overlay
br_netfilter
EOF
modprobe overlay
modprobe br_netfilter

echo "==> [3/8] Sysctl for Kubernetes networking..."
cat >/etc/sysctl.d/99-kubernetes-cri.conf <<EOF
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF
sysctl --system >/dev/null

echo "==> [4/8] Install dependencies..."
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y -qq \
  apt-transport-https \
  ca-certificates \
  curl \
  gnupg \
  jq \
  git \
  vim \
  htop

echo "==> [5/8] Install containerd..."
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
chmod a+r /etc/apt/keyrings/docker.gpg
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" \
  >/etc/apt/sources.list.d/docker.list
apt-get update -qq
apt-get install -y -qq containerd.io
mkdir -p /etc/containerd
containerd config default >/etc/containerd/config.toml
sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
systemctl restart containerd
systemctl enable containerd

echo "==> [6/8] Install kubeadm, kubelet, kubectl v${K8S_VERSION}..."
curl -fsSL "https://pkgs.k8s.io/core:/stable:/v${K8S_VERSION}/deb/Release.key" | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v${K8S_VERSION}/deb/ /" \
  >/etc/apt/sources.list.d/kubernetes.list
apt-get update -qq
apt-get install -y -qq kubelet kubeadm kubectl
apt-mark hold kubelet kubeadm kubectl

echo "==> [7/8] Enable kubelet..."
systemctl enable kubelet

echo "==> [8/8] Node bootstrap complete."
echo "    Hostname: $(hostname)"
echo "    NODE_ROLE: ${NODE_ROLE:-unset}"
echo "    K8S_VERSION: ${K8S_VERSION}"
