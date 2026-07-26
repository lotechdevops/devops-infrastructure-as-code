# devops-infrastructure-as-code

Repositório de estudos e portfólio — infraestrutura como código pra um homelab Kubernetes rodado sobre KVM/libvirt, com automação via Ansible e stack de observabilidade completa (Prometheus, Alertmanager, Grafana).

## Visão geral

Um cluster Kubernetes (kubeadm) provisionado em VMs sobre dois hosts físicos na mesma rede, com storage compartilhado via NFS e uma stack de monitoramento com alertas enviados pro Telegram. Todo o provisionamento — servidor NFS, provisioner de storage e a stack de observabilidade — é automatizado via Ansible.

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

## Estrutura do repositório

```
.
├── vagrant/
│   ├── README.md
│   ├── Vagrantfile
│   └── common.sh
├── ansible/
│   ├── readme.md                      
│   ├── ansible.cfg
│   ├── inventory/
│   │   └── hosts.yml
│   ├── main.yml
│   └── roles/
│       ├── nfs-server/
│       │   └── readme.md              
│       ├── nfs-provisioner/
│       │   └── readme.md
│       └── kube-prometheus-stack/
│           └── readme.md
```

## Componentes

### Ansible

Provisiona storage e a stack de observabilidade do cluster, uma role por ferramenta. Lista completa de roles, pré-requisitos e como rodar: **[ansible/readme.md](ansible/readme.md)**.

### Vagrant

Provisiona as 3 VMs do cluster (KVM/libvirt). Detalhes em **[vagrant/readme.md](vagrant/readme.md)**.
```