# metallb

Role Ansible responsável por instalar e configurar o [MetalLB](https://metallb.universe.tf/) no cluster Kubernetes, permitindo que Services do tipo `LoadBalancer` recebam um IP real e funcional em um ambiente **on-premises** (bare-metal/homelab), onde não existe um balanceador de carga nativo como nos provedores de nuvem (EKS, GKE, AKS).

## Por que o MetalLB é necessário

Em clusters hospedados em nuvem pública, criar um Service do tipo `LoadBalancer` aciona automaticamente um balanceador do provedor (ELB, NLB, etc.), que atribui um IP externo válido. Em um cluster on-premises — como este, provisionado via kubeadm em VMs KVM/libvirt — essa funcionalidade não existe nativamente: o Service fica preso em `EXTERNAL-IP: <pending>` para sempre.

O MetalLB resolve isso implementando o tipo `LoadBalancer` de forma nativa, distribuindo IPs de um pool pré-definido para os Services que precisam.

## Modo de operação

O MetalLB pode operar em dois modos:

- **Layer 2** — responde a requisições ARP na rede local, direcionando o tráfego diretamente para o pod correto. Simples, não exige suporte de roteador.
- **BGP** — integra com roteadores externos para anunciar os IPs via protocolo de roteamento. Mais robusto, mas exige infraestrutura de rede compatível.

Este role usa o **modo Layer 2**, adequado para o cenário de homelab em rede doméstica, sem necessidade de configuração adicional no roteador.

## Arquitetura do role

```
roles/metallb/
├── tasks/
│   └── main.yml
├── templates/
│   ├── ipaddresspool.yaml.j2
│   └── l2advertisement.yaml.j2
└── configuration/
    └── cfg.yaml
```

## O que o role faz

1. Carrega as variáveis de `configuration/cfg.yaml`
2. Instala o MetalLB aplicando o manifesto oficial (`metallb-native.yaml`) diretamente da release do projeto
3. Renderiza os templates de `IPAddressPool` e `L2Advertisement` com as variáveis carregadas
4. Aplica os dois recursos no cluster

## Variáveis (`configuration/cfg.yaml`)

| Variável | Descrição | Valor usado |
|---|---|---|
| `metallb.namespace` | Namespace de instalação do MetalLB | `metallb-system` |
| `metallb.ipAddressPoolName` | Nome do recurso `IPAddressPool` | `homelab-pool` |
| `metallb.l2AdvertisementName` | Nome do recurso `L2Advertisement` | `homelab-advertisement` |
| `metallb.ipRangeStart` | Primeiro IP do pool distribuído aos Services | `10.10.20.220` |
| `metallb.ipRangeEnd` | Último IP do pool distribuído aos Services | `10.10.20.230` |

> ⚠️ **Importante:** essa faixa de IPs precisa estar dentro da mesma rede do cluster, mas **fora** do intervalo já usado pelos nós (control-plane e workers) e de qualquer outro dispositivo da rede, para evitar conflito de IP.

## Uso

```bash
ansible-playbook main.yml --tags metallb
```

## Validação

```bash
# Pods controller e speaker rodando
kubectl get pods -n metallb-system

# Recursos de configuração aplicados
kubectl get ipaddresspools -n metallb-system
kubectl get l2advertisements -n metallb-system
```

### Teste real — expor um Service como LoadBalancer

```bash
kubectl expose deployment <nome-deployment> --type=LoadBalancer --name=teste-metallb --port=80
kubectl get svc teste-metallb -w
```

Esperado: o campo `EXTERNAL-IP` deixa de ficar `<pending>` e recebe um IP dentro da faixa `10.10.20.220–10.10.20.230` em poucos segundos.

Depois de validar, remova o Service de teste:

```bash
kubectl delete svc teste-metallb
```

## Próximo passo

Com o MetalLB atribuindo IPs, a próxima peça da stack é o **Ingress-NGINX Controller**, que será exposto como `Service` do tipo `LoadBalancer` — recebendo automaticamente um IP deste pool — servindo de porta de entrada única para todas as aplicações do cluster (Prometheus, Alertmanager, Grafana), com TLS emitido pelo `cert-manager`.

## Referência

Documentação completa do processo, com contexto adicional e capturas de tela, disponível no blog:
[devopsr66.com — Instalação e Configuração do MetalLB](https://www.devopsr66.com/docs/kubernetes/hands-on/lab-metallb-ingress-cloudflare/instalacao-configuracao-metallb)