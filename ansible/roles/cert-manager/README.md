# cert-manager

Role Ansible responsável por instalar e configurar o [cert-manager](https://cert-manager.io/) no cluster Kubernetes, automatizando a emissão e renovação de certificados TLS via Let's Encrypt, usando desafio **DNS-01** com a Cloudflare como provedor DNS.

## Por que DNS-01 em vez de HTTP-01?

O desafio HTTP-01 exige que a porta 80 esteja acessível publicamente para o servidor da Let's Encrypt validar o domínio. Como este cluster roda em uma rede doméstica sem exposição pública configurada (Ingress ainda pendente na época da implementação), o desafio **DNS-01** foi escolhido por não depender de nenhuma exposição externa: o cert-manager cria um registro `TXT` temporário via API da Cloudflare para provar a posse do domínio.

```
cert-manager → Cloudflare API (cria TXT) → Let's Encrypt valida → certificado emitido
```

Essa abordagem também permite emitir certificados **wildcard**, que o HTTP-01 não suporta.

## Arquitetura

```
roles/cert-manager/
├── tasks/
│   └── main.yml                    # instalação + configuração
├── templates/
│   ├── clusterissuer-staging.yaml.j2
│   └── clusterissuer-prod.yaml.j2
├── defaults/
│   └── main.yml                    # variáveis não sensíveis
└── README.md
```

As variáveis sensíveis (token da API Cloudflare) **não** ficam neste role — são gerenciadas via **Ansible Vault** em `group_vars/all/vault.yml`, na raiz do projeto Ansible.

## O que o role faz

1. Adiciona o repositório Helm do Jetstack e atualiza o cache
2. Instala o cert-manager via Helm (versão fixada, CRDs incluídos)
3. Cria um `Secret` no namespace `cert-manager` com o token da API Cloudflare (via Vault)
4. Cria dois `ClusterIssuer`:
   - `letsencrypt-staging` — ambiente de testes, rate limit alto, certificados **não confiáveis** pelo navegador
   - `letsencrypt-prod` — ambiente de produção, rate limit baixo (5 falhas/hora, 50 certificados/domínio/semana), certificados confiáveis

## Pré-requisitos

- Cluster Kubernetes com `kubectl` configurado no host que executa o Ansible
- Collection `kubernetes.core` instalada:
  ```bash
  ansible-galaxy collection install kubernetes.core
  ```
- Domínio gerenciado pela Cloudflare
- Token de API da Cloudflare com permissão **Zone → DNS → Edit**, restrito à zona do domínio (template "Edit zone DNS")

## Variáveis

### `defaults/main.yml` (públicas, versionadas)

| Variável | Descrição | Exemplo |
|---|---|---|
| `cert_manager_namespace` | Namespace de instalação | `cert-manager` |
| `cert_manager_version` | Versão do chart Helm (fixada por idempotência) | `v1.16.2` |
| `cloudflare_email` | E-mail da conta ACME | `seu-email@exemplo.com` |
| `cloudflare_domain` | Domínio base gerenciado na Cloudflare | `seudominio.com` |

### `group_vars/all/vault.yml` (sensíveis, criptografadas com Ansible Vault)

| Variável | Descrição |
|---|---|
| `vault_cloudflare_api_token` | Token da API Cloudflare (escopo DNS Edit) |

> O token nunca é versionado em texto plano. O arquivo `vault.yml` pode ser commitado normalmente — está protegido com AES256 e só é legível com a senha do vault, que existe apenas localmente em `~/.vault_pass.txt` (fora do repositório).

## Uso

```bash
# Instalar/atualizar o cert-manager e os ClusterIssuers
ansible-playbook main.yml --tags cert-manager
```

## Validação

```bash
# Pods do cert-manager rodando
kubectl get pods -n cert-manager

# CRDs instaladas
kubectl get crds | grep cert-manager

# ClusterIssuers prontos
kubectl get clusterissuer
# NAME                  READY   AGE
# letsencrypt-prod      True    ...
# letsencrypt-staging   True    ...
```

### Teste ponta a ponta

Para validar a emissão real de um certificado (recomendado sempre testar primeiro com `letsencrypt-staging`, evitando gastar o rate limit de produção):

```bash
kubectl apply -f - <<EOF
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: test-certificate
  namespace: default
spec:
  secretName: test-certificate-tls
  issuerRef:
    name: letsencrypt-staging
    kind: ClusterIssuer
  dnsNames:
    - "teste.seudominio.com"
EOF

kubectl get certificate test-certificate -w
```

Esperado: `READY: True` em 1–3 minutos. Após validar, remova os recursos de teste:

```bash
kubectl delete certificate test-certificate -n default
kubectl delete secret test-certificate-tls -n default
```

## Uso em produção (Ingress)

Para emitir certificados automaticamente ao expor uma aplicação, basta referenciar o `ClusterIssuer` de produção via annotation no `Ingress`:

```yaml
metadata:
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt-prod
```

## Boas práticas aplicadas

- **Idempotência**: versão do chart fixada, `changed_when: false` nas tasks de leitura
- **Segurança**: segredo isolado via Ansible Vault, nunca versionado em texto plano; token com escopo mínimo (DNS Edit, zona específica)
- **Progressão segura**: sempre validar em `staging` antes de emitir em `prod`, evitando estourar rate limit da Let's Encrypt