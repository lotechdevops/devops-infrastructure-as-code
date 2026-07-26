# nfs-provisioner

Instala o `nfs-subdir-external-provisioner` **dentro do cluster Kubernetes**, via Helm — a peça que faz o cluster saber criar volumes automaticamente a partir do NFS já exportado (role `nfs-server`).

## O que essa role faz

1. Cria o namespace `nfs-provisioning`
2. Adiciona e atualiza o repositório Helm `nfs-subdir-external-provisioner`
3. Instala o chart, apontando pro IP e caminho do servidor NFS
4. Cria a `StorageClass` chamada `nfs-storage`

## Conecta via

`hosts: localhost` + `connection: local` — fala com a API do cluster via `kubectl`/`helm`, não SSH. **Não precisa** de `become: true`.

## Depende de

A role `nfs-server` já ter rodado (o NFS precisa estar exportado antes do provisioner tentar montá-lo).

## Rodar isoladamente

```bash
ansible-playbook main.yml --tags nfs-provisioner
```

## Validação

```bash
kubectl get storageclass
# deve mostrar "nfs-storage"

kubectl get pods -n nfs-provisioning
# pod do provisioner deve estar Running
```

## Pré-requisitos específicos

- `kubectl`/`helm` instalados e configurados na máquina de controle (`KUBECONFIG` apontando pro cluster)
- Lib Python `kubernetes` instalada (`pip3 install kubernetes --break-system-packages`) — necessária pro módulo `kubernetes.core.k8s`

## Problemas conhecidos

- Pod preso em `FailedMount` com erro de "bad option" → falta `nfs-common` no nó do cluster onde o pod foi agendado (ver role `nfs-server`, não é problema dessa role em si)