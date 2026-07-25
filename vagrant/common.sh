#!/bin/bash
set -e

# Desabilitar swap tradicional (fstab)
swapoff -a
sed -i '/ swap / s/^/#/' /etc/fstab

# Desabilitar zram — algumas imagens cloud vêm com swap comprimido em
# memória (zram) habilitado por padrão, gerenciado por um serviço systemd
# separado do /etc/fstab. O swapoff/fstab acima NÃO cobre isso.
systemctl disable --now zram-config.service 2>/dev/null || true
systemctl disable --now zramswap.service 2>/dev/null || true
apt purge -y zram-config 2>/dev/null || true
swapoff -a

# Módulos de kernel necessários
cat <<EOF2 | tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF2
modprobe overlay
modprobe br_netfilter

# Configurações de rede exigidas pelo kubeadm
cat <<EOF2 | tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF2
sysctl --system

# Instalar containerd
apt update
apt install -y containerd

# nfs-common: fornece o helper mount.nfs, necessário pro kubelet conseguir
# montar volumes NFS nesse nó (usado pelo nfs-subdir-external-provisioner
# e por qualquer PVC com storageClass nfs-storage)
apt install -y nfs-common

mkdir -p /etc/containerd
containerd config default | tee /etc/containerd/config.toml
sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
systemctl restart containerd
systemctl enable containerd

# Repositório oficial do Kubernetes (v1.33)
apt install -y apt-transport-https ca-certificates curl gpg
mkdir -p /etc/apt/keyrings
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.33/deb/Release.key | \
  gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.33/deb/ /" | \
  tee /etc/apt/sources.list.d/kubernetes.list

apt update
apt install -y kubelet kubeadm kubectl
apt-mark hold kubelet kubeadm kubectl

# Rota estática de volta pra LAN do host2 (persiste no reboot)
# Necessária porque a rede "k8s-routed" (modo route, sem NAT) não sabe
# automaticamente como devolver pacotes pra 192.168.12.0/24
cat <<'EOF2' | tee /etc/systemd/system/route-to-host2.service
[Unit]
Description=Rota estática de volta para a LAN do host2
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
ExecStart=/sbin/ip route replace 192.168.12.0/24 via 10.10.20.1 dev eth1
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF2
systemctl enable route-to-host2.service
systemctl start route-to-host2.service

# Trava de segurança extra contra swap: mesmo com fstab comentado e zram
# desabilitado, algo (cloud-init reprocessando mounts, ou uma unit de swap
# separada) pode religar a swap num boot futuro. Este serviço força
# swapoff -a sempre, ANTES do kubelet subir — independente da causa.
cat <<'EOF2' | tee /etc/systemd/system/disable-swap.service
[Unit]
Description=Garante swap desligada no boot (independente de fstab/cloud-init)
DefaultDependencies=no
After=local-fs.target
Before=kubelet.service

[Service]
Type=oneshot
ExecStart=/sbin/swapoff -a
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF2
systemctl enable disable-swap.service
systemctl start disable-swap.service