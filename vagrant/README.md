# Vagrant — Provisionamento do Cluster Kubernetes

Provisiona as 3 VMs (1 control-plane + 2 workers) que formam o cluster Kubernetes via `kubeadm`, usando KVM/libvirt como hipervisor.

```
Host físico 1 (KVM/libvirt)              Host físico 2 (controle)
├─ VM k8s-cp                              ├─ Ansible (roda os playbooks)
├─ VM k8s-worker1                         └─ kubectl (acesso remoto ao cluster)
├─ VM k8s-worker2
└─ Servidor NFS (/nfs/k8s-storage)
        │
        ▼
Cluster Kubernetes
├─ nfs-subdir-external-provisioner → StorageClass "nfs-storage"
└─ kube-prometheus-stack
    ├─ Prometheus
    ├─ Alertmanager → Telegram
    └─ Grafana
```





## Arquivos

| Arquivo | O que faz |
|---|---|
| `Vagrantfile` | Declara as 3 VMs (nome, IP, memória, CPUs), a rede virtual entre elas e o provider (libvirt) |
| `common.sh` | Script rodado automaticamente em cada VM na primeira criação — prepara o sistema pro Kubernetes (desabilita swap, instala containerd/kubeadm/kubelet/kubectl, configura rotas de rede) |

## O que o `Vagrantfile` declara

- **3 VMs**: `k8s-cp` (4GB/2vCPU), `k8s-worker1` e `k8s-worker2` (3GB/2vCPU cada), todas Ubuntu 22.04
- **Rede**: sub-rede própria `10.10.20.0/24`, em modo `route` do libvirt (não bridge — necessário porque o host físico usa Wi-Fi, que não suporta bridge de VMs)
- **Provider**: `qemu:///system` explícito, evitando o ambiente `qemu:///session` (isolado por usuário, sem acesso às redes/VMs "do sistema")

## O que o `common.sh` faz, em ordem

1. Desabilita swap (fstab tradicional + zram, quando presente)
2. Carrega módulos de kernel exigidos pelo kubeadm (`overlay`, `br_netfilter`) e ajusta `sysctl`
3. Instala e configura o `containerd` (cgroup driver `systemd`)
4. Instala `nfs-common` (necessário pro nó conseguir montar volumes NFS do cluster)
5. Adiciona o repositório oficial do Kubernetes (canal stable v1.33) e instala `kubelet`, `kubeadm`, `kubectl`
6. Cria um serviço systemd (`route-to-host2.service`) que garante a rota de volta pra LAN do host de controle, persistente entre reboots
7. Cria um serviço systemd (`disable-swap.service`) que força swap desligada antes do `kubelet` subir, em todo boot — proteção contra a swap voltar por conta própria

## Pré-requisitos no host físico

```bash
# KVM/libvirt
sudo apt update
sudo apt install -y qemu-kvm libvirt-daemon-system libvirt-clients bridge-utils virtinst virt-manager
sudo usermod -aG libvirt,kvm $USER
sudo systemctl enable --now libvirtd

# Forçar ambiente "system" (evita cair em qemu:///session)
echo 'export LIBVIRT_DEFAULT_URI="qemu:///system"' >> ~/.bashrc
source ~/.bashrc

# Vagrant + plugin libvirt
wget -O- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com jammy main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt update && sudo apt install -y vagrant
sudo apt install -y libvirt-dev ruby-dev build-essential
vagrant plugin install vagrant-libvirt

# IP forwarding, necessário pro modo routed
sudo sysctl -w net.ipv4.ip_forward=1
echo "net.ipv4.ip_forward=1" | sudo tee /etc/sysctl.d/99-k8s-route.conf
```

> ⚠️ Depois de adicionar seu usuário aos grupos `libvirt`/`kvm`, é necessário **logout/login completo** (ou reboot) — `newgrp` sozinho não é suficiente pra aplicar em toda a sessão gráfica/terminal.

## Como subir

```bash
cd vagrant/
vagrant up --provider=libvirt
```

Leva de 2 a 5 minutos na primeira vez (download da box + provisionamento das 3 VMs em paralelo).

## Depois de subir

Inicializar o cluster (fora do escopo do Vagrant — feito manualmente via `kubeadm`):

```bash
vagrant ssh k8s-cp

sudo kubeadm init \
  --pod-network-cidr=192.168.0.0/16 \
  --apiserver-advertise-address=10.10.20.11 \
  --apiserver-cert-extra-sans=10.10.20.11
```

Guarde o comando `kubeadm join` impresso no final — necessário pros dois workers.

## Juntar os workers ao cluster

Em **cada worker** (`vagrant ssh k8s-worker1`, depois `vagrant ssh k8s-worker2`), rode o comando `kubeadm join` que foi impresso no final do `kubeadm init` do control-plane:

```bash
sudo kubeadm join 10.10.20.11:6443 \
  --token <TOKEN> \
  --discovery-token-ca-cert-hash sha256:<HASH>
```

> ⚠️ O token expira em **24h**. Se for aplicar depois desse prazo, gere um novo direto no control-plane:
> ```bash
> kubeadm token create --print-join-command
> ```

Depois de rodar nos dois workers, valide no control-plane que os 3 nós entraram:

```bash
kubectl get nodes -o wide
```

Os 3 devem aparecer (podem levar 1-2 minutos pra virar `Ready`, já que ainda falta instalar o CNI — ver README raiz do repositório, seção do Calico/Tigera Operator).

## Comandos úteis

```bash
vagrant status              # ver estado das 3 VMs
vagrant ssh <nome-da-vm>     # entrar numa VM (k8s-cp, k8s-worker1, k8s-worker2)
vagrant halt                 # desligar as VMs (desligamento limpo)
vagrant destroy -f           # apagar as VMs por completo
vagrant provision <nome>     # re-rodar o common.sh numa VM já existente
```