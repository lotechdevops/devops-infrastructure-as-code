# kube-prometheus-stack

Instala Prometheus, Alertmanager e Grafana **dentro do cluster Kubernetes**, via Helm, usando o chart oficial da comunidade.

## O que essa role faz

1. Cria o namespace `observabilidade`
2. Adiciona e atualiza o repositório Helm `prometheus-community`
3. Aplica o secret com as credenciais de admin do Grafana (`files/secret-grafana.yaml`)
4. Instala o chart `prometheus-community/kube-prometheus-stack`, com versão fixada, usando `files/values.yaml`

## Conecta via

`hosts: localhost` + `connection: local` — fala com a API do cluster via `kubectl`/`helm`. **Não precisa** de `become: true`.

## Depende de

As roles `nfs-server` e `nfs-provisioner` já terem rodado — os PVCs do Prometheus, Alertmanager e Grafana usam a `StorageClass` `nfs-storage`.

## Arquivos

| Arquivo | Papel |
|---|---|
| `files/values.yaml` | Configuração do chart: retenção, storage, admin do Grafana. Ingress **desabilitado de propósito** (acesso via port-forward, por enquanto) |
| `files/secret-grafana.yaml` | Credenciais de admin do Grafana, em base64 |

## Por que esse chart e não Bitnami

O catálogo público do Bitnami (`bitnami/kube-prometheus`, `bitnami/grafana`) foi descontinuado em setembro/2025. `prometheus-community/kube-prometheus-stack` é o chart padrão de mercado — um único chart "guarda-chuva" que já empacota Prometheus Operator, Prometheus, Alertmanager e Grafana juntos.

## Versão do chart

Fixada via variável `kube_prometheus_stack_version`, declarada na play (em `main.yml`) — evita que o playbook traga uma versão diferente/com breaking changes ao rodar meses depois. Pra atualizar:

```bash
helm search repo prometheus-community/kube-prometheus-stack --versions | head -5
```

## Rodar isoladamente

```bash
ansible-playbook main.yml --tags kube-prometheus-stack
```

## Validação

```bash
kubectl get pods -n observabilidade
```

## Acessar (sem ingress, via port-forward)

```bash
kubectl port-forward -n observabilidade svc/kube-prometheus-stack-grafana 3000:80
kubectl port-forward -n observabilidade svc/kube-prometheus-stack-prometheus 9090:9090
kubectl port-forward -n observabilidade svc/kube-prometheus-stack-alertmanager 9093:9093
```