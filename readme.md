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

Provisiona storage e a stack de observabilidade do cluster, uma role por ferramenta. Lista completa de roles, pré-requisitos e como rodar: **[ansible/README.md](ansible/README.md)**.

### Vagrant

Provisiona as 3 VMs do cluster (KVM/libvirt). Detalhes em **[vagrant/README.md](vagrant/README.md)**.

### Kubernetes manifests — Alertmanager

Aplicados diretamente (fora do Ansible), configuram o roteamento de alertas:

- **`secret.yaml`**: token do bot do Telegram (placeholder — substituir antes de aplicar, nunca commitar o token real)
- **`telegram-alertmanager-config.yaml`**: `AlertmanagerConfig` (CRD do Prometheus Operator) roteando alertas com label `channel: telegram-homelab` pro Telegram, com inibição de `warning` quando já existe um `critical` da mesma instância
- **`prometheus-rule.yaml`**: regras de alerta de CPU, memória e disco (thresholds `warning`/`critical`) usando métricas do `node-exporter`

## Decisões técnicas relevantes

- **Bitnami descontinuado**: migrado de `bitnami/kube-prometheus` + `bitnami/grafana` para o chart oficial da comunidade `prometheus-community/kube-prometheus-stack`, após a descontinuação do catálogo público Bitnami (set/2025)
- **`kubernetes.core.helm`** em vez de `community.kubernetes.helm` (collection descontinuada)
- **Versão do chart fixada** (`chart_version`) — evita que o playbook traga uma versão diferente/com breaking changes ao rodar meses depois
- **Rede routed (não bridge)**: os hosts físicos usam Wi-Fi, que não suporta bridge de VMs — solução via modo `route` do libvirt + rota estática entre os hosts

## Status / pendências

- [x] Adicionar `Vagrantfile` e `common.sh` na pasta `vagrant/`
- [ ] Corrigir threshold do alerta `CriticalDiskUsage` (atualmente igual ao `HighDiskUsage`, deveria ser mais alto)
- [ ] Ingress para acesso externo (Prometheus/Alertmanager/Grafana) — hoje via `kubectl port-forward`
- [ ] Documentação detalhada do processo de criação do cluster (Vagrant + kubeadm + troubleshooting)

## Como rodar

```bash
cd ansible
ansible-playbook main.yml --tags nfs-server
ansible-playbook main.yml --tags nfs-provisioner
ansible-playbook main.yml --tags kube-prometheus-stack

kubectl apply -f kubernetes-manifests/alertmanager/
```