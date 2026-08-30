# Ansible — Provisionamento de Storage e Observabilidade

Automatiza a configuração do cluster depois que as VMs já estão de pé (ver `../vagrant`) e o `kubeadm` já rodou. Cada ferramenta/etapa vive numa role independente — ver o README de cada uma pra detalhes específicos.

## Estrutura

```
ansible/
├── ansible.cfg
├── inventory/
│   └── hosts.yml
├── main.yml
└── roles/
    ├── nfs-server/                 
    ├── nfs-provisioner/            
    └── kube-prometheus-stack/
    └── cert-manager/
    └── metallb/

```

## Roles

| Role | O que faz | Conecta via |
|---|---|---|
| [`nfs-server`](roles/nfs-server/README.md) | Configura o servidor NFS no host físico (servidor) | SSH |
| [`nfs-provisioner`](roles/nfs-provisioner/README.md) | Instala o provisioner NFS no cluster, cria a StorageClass `nfs-storage` | API do cluster (localhost) |
| [`kube-prometheus-stack`](roles/kube-prometheus-stack/README.md) | Instala Prometheus + Alertmanager + Grafana | API do cluster (localhost) |
| [`cert-manager`](roles/cert-manager/README.md) | Instala o cert-manager e configura a emissão de certificados | API do cluster (localhost) |
| [`metallb`](roles/metallb/README.md) | Instala o MetalLB e configura os serviços | API do cluster (localhost) |

## Duas formas diferentes de execução

| | Roles que usam SSH (`nfs-server`) | Roles que usam `localhost` (as outras) |
|---|---|---|
| `hosts:` no `main.yml` | Grupo do inventário | `localhost` |
| Conecta via | SSH numa máquina remota | Executa localmente (`connection: local`) |
| O que faz | Mexe no sistema operacional (pacotes, arquivos, serviços) | Fala com a API do Kubernetes via `kubectl`/`helm` |
| Precisa de `become: true`? | Sim | Não |

## Pré-requisitos gerais

**Na máquina de controle** (onde o Ansible roda):

```bash
pip3 install ansible kubernetes --break-system-packages
ansible-galaxy collection install kubernetes.core

curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

export KUBECONFIG=~/.kube/config-lab
kubectl get nodes    # confirma acesso ao cluster antes de rodar qualquer role
```

**No `inventory/hosts.yml`**, ajuste o IP, usuário e caminho da chave SSH do host físico (servidor) pro seu ambiente.

## Como rodar

```bash
cd ansible/

# Tudo de uma vez
ansible-playbook main.yml

# Ou por etapa, usando as tags (respeitando a ordem de dependência)
ansible-playbook main.yml --tags <tag-role> (Ex: ansible-playbook main.yml --tags nfs-server)

```

Simulação antes de aplicar (opcional — tasks em cadeia podem falhar no `--check`, é limitação conhecida do dry-run):

```bash
ansible-playbook main.yml --check --diff
```