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
│   ├── README.md                      # índice — visão geral, pré-requisitos, como rodar
│   ├── ansible.cfg
│   ├── inventory/
│   │   └── hosts.yml
│   ├── main.yml
│   └── roles/
│       ├── nfs-server/
│       │   └── README.md              # detalhes específicos dessa role
│       ├── nfs-provisioner/
│       │   └── README.md
│       └── kube-prometheus-stack/
│           └── README.md
└── kubernetes-manifests/
    └── alertmanager/
        ├── secret.yaml                       # Token do bot do Telegram
        ├── telegram-alertmanager-config.yaml  # Roteamento de alertas pro Telegram
        └── prometheus-rule.yaml              # Regras de alerta (CPU, memória, disco)
```

## Componentes

### Ansible

Provisiona storage e a stack de observabilidade do cluster, uma role por ferramenta. Lista completa de roles, pré-requisitos e como rodar: **[ansible/readme.md](ansible/readme.md)**.

### Vagrant

Provisiona as 3 VMs do cluster (KVM/libvirt). Detalhes em **[vagrant/README.md](vagrant/readme.md)**.

### Kubernetes manifests — Alertmanager

Aplicados diretamente (fora do Ansible), configuram o roteamento de alertas:

- **`secret.yaml`**: token do bot do Telegram (placeholder — substituir antes de aplicar, nunca commitar o token real)
- **`telegram-alertmanager-config.yaml`**: `AlertmanagerConfig` (CRD do Prometheus Operator) roteando alertas com label `channel: telegram-homelab` pro Telegram, com inibição de `warning` quando já existe um `critical` da mesma instância
- **`prometheus-rule.yaml`**: regras de alerta de CPU, memória e disco (thresholds `warning`/`critical`) usando métricas do `node-exporter`


