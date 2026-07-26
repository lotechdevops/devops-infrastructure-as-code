# devops-infrastructure-as-code

Repositório de infraestrutura como código para automatizar instalação de ferramentas no Kubernetes via Ansible e Vagrant para provisionamento das VMs.

## Estrutura do repositório

```
├── vagrant/
│   ├── README.md
│   ├── Vagrantfile
│   └── common.sh
├── ansible/
│   ├── README.md
│   ├── ansible.cfg
│   ├── inventory/
│   │   └── hosts.yml
│   ├── main.yml
│   └── roles/
│       ├── nfs-server/
│       │   └── README.md
│       ├── nfs-provisioner/
│       │   └── README.md
│       └── kube-prometheus-stack/
│           └── README.md
```

## Vagrant

Utilizado para provisionamento de instâncias VMs no host físico para realizar a instalação de Cluster Kubernetes (kubeadm) utilizando o hipervisor KVM/libvirt. Detalhes: [vagrant/README.md](vagrant/README.md)

## Ansible

Provisiona storage e observabilidade do cluster, uma role por ferramenta. Lista de roles, pré-requisitos e como rodar: [ansible/README.md](ansible/README.md)
