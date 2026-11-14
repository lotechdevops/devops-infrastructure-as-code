# devops-infrastructure-as-code

Infraestrutura do meu homelab Kubernetes, construída **do zero com Vagrant e Ansible**. Este repositório é a base didática do projeto: mostra como o cluster nasce e como cada componente foi instalado e entendido, passo a passo.

> **Evolução do projeto:** os aplicativos de infraestrutura (MetalLB, cert-manager, Traefik, Prometheus/Grafana e outros) que aqui eram instalados pelo Ansible hoje são gerenciados por **GitOps com Argo CD**, no repositório [`gitops-homelab`](https://github.com/lotechdevops/gitops-homelab). Este repositório continua como a camada de **provisionamento do cluster** e como material de estudo.

---

## Como as peças se encaixam

```text
┌──────────────────────────────┐        ┌──────────────────────────────┐
│ devops-infrastructure-as-code│        │ gitops-homelab               │
│ (este repositório)           │        │ (Argo CD)                    │
│                              │        │                              │
│  Vagrant  ─► VMs             │        │  Git ─► Argo CD ─► cluster   │
│  Ansible  ─► cluster K8s     │ ─────► │  MetalLB, Traefik,           │
│              + base de rede  │        │  cert-manager, Prometheus... │
│              e storage       │        │  Sealed Secrets              │
└──────────────────────────────┘        └──────────────────────────────┘
      1. cria o cluster                    2. entrega as aplicações
```

| Camada | Ferramenta | Onde está |
|---|---|---|
| Máquinas virtuais | Vagrant | `vagrant/` |
| Configuração dos nós e do cluster | Ansible | `ansible/` |
| Aplicações de infraestrutura | Argo CD (GitOps) | repositório `gitops-homelab` |
| Exercícios de Kubernetes | manifestos YAML | `labs/` |

---

## Ambiente

- Cluster **Kubernetes (kubeadm)** com 3 nós, em VMs criadas pelo **Vagrant** <!-- AJUSTAR: provider (libvirt/VirtualBox), SO dos nós, quantos control-plane -->
- Rede de pods: **Calico**
- Servidor **NFS** para volumes persistentes (StorageClass `nfs-storage`)
- IPs de LoadBalancer: **MetalLB** (faixa `10.10.20.200-220`)

---

## Estrutura do repositório

```text
.
├── ansible/                  # automação do cluster
│   ├── ansible.cfg
│   ├── inventory/hosts.yml   # inventário (nós do cluster)
│   ├── main.yml              # playbook principal
│   └── roles/
│       ├── nfs-server/       # servidor NFS
│       ├── nfs-provisioner/  # provisionamento dinâmico de volumes
│       ├── metallb/          # IPs de LoadBalancer
│       ├── cert-manager/     # certificados (Let's Encrypt)
│       └── kube-prometheus-stack/  # observabilidade
├── vagrant/                  # VMs do laboratório
│   ├── vagrantfile
│   └── common.sh
└── labs/                     # exercícios de Kubernetes
    ├── hpa/                  # autoscaling horizontal
    ├── resource-quota/       # quotas e limites
    ├── cert-manager/         # emissão de certificados
    └── metallb/              # exposição de serviços
```

Cada role do Ansible tem o seu próprio `README.md`, explicando o que faz e como foi pensado.

---

## O que cada parte ensina

| Parte | Conceitos praticados |
|---|---|
| `vagrant/` | Infraestrutura como código para VMs, rede e provisionamento inicial |
| `ansible/` | Idempotência, roles, variáveis, templates Jinja2, inventário |
| `ansible/roles/nfs-*` | Storage persistente no Kubernetes (StorageClass, PV e PVC dinâmicos) |
| `ansible/roles/metallb` | Serviços `LoadBalancer` em ambiente bare metal |
| `ansible/roles/cert-manager` | TLS automático, desafio DNS01, ClusterIssuers |
| `ansible/roles/kube-prometheus-stack` | Métricas, alertas e dashboards |
| `labs/` | HPA, ResourceQuota e exposição de serviços |

---

## Como usar

> **Pré-requisitos:** Vagrant, Ansible e o provider de virtualização instalados. <!-- AJUSTAR: versões testadas -->

```bash
# 1. Subir as VMs
cd vagrant
vagrant up

# 2. Configurar o cluster
cd ../ansible
ansible-playbook -i inventory/hosts.yml main.yml   # AJUSTAR: tags/roles, se houver
```

Os aplicativos de infraestrutura são entregues depois, pelo Argo CD (veja o `gitops-homelab`).

---

## Segredos

**Nenhuma credencial é versionada.** Valores sensíveis ficam fora do repositório, e onde um arquivo é necessário existe um modelo (`*.example`) com valores de exemplo. No cluster, os segredos são gerenciados com **Sealed Secrets** no repositório `gitops-homelab`.

---

## Contexto

Projeto de estudo documentado também no blog [devopsr66.com](https://devopsr66.com).

- GitHub: [@lotechdevops](https://github.com/lotechdevops)