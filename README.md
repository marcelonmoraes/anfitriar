# Anfitriar

Guias digitais para anfitriões de hospedagem.

## Requisitos

* Ruby (ver `.ruby-version`)
* PostgreSQL

## Configuração

```bash
bin/setup
bin/rails db:seed
bin/dev
```

## Variáveis de ambiente

Em desenvolvimento, copie o modelo e preencha:

```bash
cp .env.example .env
```

O `.env` é ignorado pelo Git. Em produção, defina as variáveis no servidor.

### Integração Asaas (assinaturas)

| Variável | Obrigatória | Descrição |
|---|---|---|
| `ASAAS_API_KEY` | sim | Chave de API. **Somente backend** — nunca exposta em views ou JS. |
| `ASAAS_WEBHOOK_SECRET` | sim | Token de autenticação configurado no webhook do painel Asaas. Recebido no header `asaas-access-token`. |
| `ASAAS_PUBLIC_KEY` | não | Chave pública, caso a tokenização passe a ser feita no browser. |
| `ASAAS_ENVIRONMENT` | não | `production` usa a API real; qualquer outro valor usa o sandbox. Por padrão segue o `RAILS_ENV`. |

O webhook deve apontar para `POST /webhooks/asaas` com os eventos
`PAYMENT_CONFIRMED`, `PAYMENT_RECEIVED`, `PAYMENT_OVERDUE`, `PAYMENT_REFUNDED`,
`SUBSCRIPTION_CREATED`, `SUBSCRIPTION_UPDATED` e `SUBSCRIPTION_DELETED`.

As notificações do Asaas são desativadas por cliente (`notificationDisabled`):
toda comunicação com o anfitrião sai pela plataforma via `SubscriptionMailer`.

## Testes

```bash
bundle exec rspec
bundle exec rubocop
bundle exec brakeman
```
