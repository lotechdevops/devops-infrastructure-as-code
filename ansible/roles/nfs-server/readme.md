# nfs-server

Instala e configura o servidor NFS **no host físico** (fora do cluster Kubernetes), exportando um diretório pra sub-rede onde vivem as VMs do cluster.

## O que essa role faz

1. Instala `nfs-kernel-server` e `nfs-common`
2. Cria o diretório exportado (`/nfs/k8s-storage`) com dono `nobody:nogroup`
3. Configura `/etc/exports`, restrito à sub-rede das VMs — **não** wildcard `*`
4. Aplica com `exportfs -rav` e garante o serviço habilitado no boot
5. Libera as portas necessárias no `ufw`, só se o firewall estiver ativo

## Conecta via

SSH no host físico — grupo `nfsServer` no inventário (`hosts: nfsServer`, `become: true`).

## Export resultante

```
/nfs/k8s-storage 10.10.20.0/24(rw,sync,no_subtree_check,no_root_squash)
```

- `10.10.20.0/24`: só a sub-rede das VMs acessa, não a rede inteira
- `no_root_squash`: necessário pro provisioner do Kubernetes (que escreve como root) conseguir criar subpastas

## Rodar isoladamente

```bash
ansible-playbook main.yml --tags nfs-server
```

## Validação

```bash
ssh <usuario>@<ip-do-host> "sudo exportfs -v"
ssh <usuario>@<ip-do-host> "sudo systemctl status nfs-kernel-server"
```

## Pré-requisitos específicos

- Acesso SSH por chave (sem senha) da máquina de controle até esse host
- `sudo` sem senha pro usuário do Ansible (`become: true` falha com prompt de senha interativo)

## Problemas conhecidos

- **`nfs-common` só no servidor não basta** — todo nó do cluster que for montar esse NFS (via `nfs-provisioner`) também precisa desse pacote, senão o mount falha com `bad option; ... mount.<type> helper program`
- **Sem `no_root_squash`**, o provisioner recebe "permission denied" mesmo com o diretório em `0777`