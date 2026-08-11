# Subprojeto 4 — Assinaturas Asaas (Checkout + Webhooks)

**Data:** 2026-08-08  
**Status:** Aprovado para análise  
**Escopo:** Implementação do checkout de assinaturas via API Asaas, webhooks para ciclo de vida automático, gestão de credenciais por ambiente.

---

## 1. Visão Geral

Até o Subprojeto 3, as assinaturas eram **manuais** (Owner registra plano/ciclo/status no Admin). O Subprojeto 4 automatiza o ciclo de vida via **API de Assinaturas do Asaas** com checkout no próprio site (sem redirecionamento para página do Asaas).

### 1.1 Fluxo Principal

```
Host (trial) → Clica "Assinar" → Escolhe plano/ciclo → Checkout Asaas (no site) →
Pagamento aprovado → Webhook Asaas → Subscription.status = active → Acesso liberado
```

### 1.2 Ciclo de Vida (Webhooks)

| Evento Asaas | Ação no Anfitriar |
|--------------|-------------------|
| `SUBSCRIPTION_CREATED` | Cria/atualiza `Subscription` com `asaas_id`, status `pending` |
| `SUBSCRIPTION_ACTIVATED` | `status = active`, `activated_at = now` |
| `SUBSCRIPTION_PAYMENT_RECEIVED` | Renova `period_ends_at`, mantém `active` |
| `SUBSCRIPTION_PAYMENT_OVERDUE` | `status = past_due`, notifica host |
| `SUBSCRIPTION_CANCELLED` | `status = cancelled`, bloqueia acesso |
| `SUBSCRIPTION_DELETED` | `status = cancelled`, limpa `asaas_id` |

---

## 2. Decisões de Arquitetura & Segurança

### 2.1 Credenciais Asaas
- **Nunca no banco** — variáveis de ambiente no servidor
- Chaves: `ASAAS_API_KEY`, `ASAAS_WEBHOOK_SECRET`
- Ambiente configurado via variáveis de ambiente no servidor (staging/production)
- O código usa `ENV.fetch('ASAAS_API_KEY')` e `ENV.fetch('ASAAS_WEBHOOK_SECRET')` — o servidor define as variáveis corretas para cada ambiente; falha explícita se não definidas

### 2.2 Checkout no Próprio Site
- **Não redireciona** para `asaas.com` — usa API de assinaturas + iframe/JS do Asaas
- Host preenche cartão no site (PCI SAQ-A via iframe do Asaas)
- Tokenização via `Asaas.js` → token enviado ao backend → cria assinatura na API

### 2.3 Idempotência & Concorrência
- Webhooks processados com `SELECT ... FOR UPDATE` em `Subscription`
- `asaas_event_id` único (constraint unique) previne duplicatas
- Retry automático com exponential backoff (Sidekiq/Solid Queue)

---

## 3. Modelo de Domínio

### 3.1 Novos Campos em `Subscription`

| Campo | Tipo | Descrição |
|-------|------|-----------|
| `asaas_id` | string | ID da assinatura no Asaas (unique index) |
| `asaas_customer_id` | string | ID do cliente no Asaas |
| `asaas_subscription_id` | string | ID da subscription no Asaas |
| `payment_method` | enum | `credit_card`, `boleto`, `pix` |
| `current_period_start` | datetime | Início do período atual |
| `current_period_end` | datetime | Fim do período atual |
| `cancelled_at` | datetime | Quando foi cancelada |
| `canceled_by` | enum | `host`, `admin`, `system` |

### 3.2 Novo Model: `AsaasWebhookEvent`

| Campo | Tipo | Descrição |
|-------|------|-----------|
| `event_type` | string | Ex: `SUBSCRIPTION_ACTIVATED` |
| `asaas_event_id` | string | Unique ID do evento Asaas (unique index) |
| `payload` | jsonb | Payload completo do webhook |
| `processed_at` | datetime | Quando foi processado |
| `error_message` | text | Se falhou |
| `subscription_id` | bigint | FK para Subscription (nullable) |

---

## 4. Interface & Fluxos

### 4.1 Host — Página de Assinatura (`/account/subscription`)
- Exibe plano atual + status
- Se trial: botão "Assinar agora"
- Se ativa: botão "Cancelar", "Alterar plano"
- Se past_due: banner "Pagamento pendente", botão "Atualizar pagamento"

### 4.2 Fluxo de Checkout
1. Host clica "Assinar" → `GET /subscription/new`
2. Escolhe plano + ciclo (mensal/trimestral/semestral/anual)
3. `POST /subscription` → Backend cria `AsaasCustomer` se não existe → cria `AsaasSubscription` → retorna `checkout_url` ou `iframe_token`
4. Frontend carrega iframe/JS Asaas → Host insere cartão
5. Asaas tokeniza → callback JS → `POST /subscription/confirm` com token
6. Backend confirma na API Asaas → cria/atualiza `Subscription` com `asaas_id`
7. Redirect para `/account` com sucesso

### 4.3 Portal do Cliente Asaas (Opcional v1)
- Link "Gerenciar pagamento" → redireciona para Portal do Cliente Asaas (host vê faturas, troca cartão)

---

## 5. Webhooks — Implementação

### 5.1 Endpoint
- `POST /webhooks/asaas` (público, sem autenticação Host)
- Validação HMAC: `X-Asaas-Signature` vs `config.credentials.asaas_webhook_secret`

### 5.2 Processamento Assíncrono (Solid Queue)
```ruby
# Job
class AsaasWebhookJob < ApplicationJob
  def perform(event)
    # Idempotência
    return if AsaasWebhookEvent.exists?(asaas_event_id: event.id)
    
    AsaasWebhookEvent.create!(...)
    
    case event.type
    when "SUBSCRIPTION_ACTIVATED" then handle_activated(event)
    when "SUBSCRIPTION_PAYMENT_RECEIVED" then handle_payment(event)
    when "SUBSCRIPTION_PAYMENT_OVERDUE" then handle_overdue(event)
    when "SUBSCRIPTION_CANCELLED" then handle_cancelled(event)
    end
  end
end
```

### 5.3 Retry & Dead Letter
- Retry: 5x com backoff exponencial (30s, 2m, 10m, 30m, 1h)
- Após 5 falhas → `AsaasWebhookEvent.update!(error_message: ...)` + alerta no Admin

---

## 6. Admin — Mudanças

### 6.1 Novo: Detalhes da Assinatura no Admin
- Em `/admin/hosts/:id` → mostra `asaas_id`, `asaas_customer_id`, último webhook processado
- Botão "Reenviar webhook" (reprocessa último evento)

### 6.2 Dashboard Financeiro — Atualização
- MRR calculado a partir de `Subscription.where(status: :active).sum(:mrr_cents)` (já existe)
- Nova coluna: "Fonte" (Manual vs Asaas)

---

## 7. Arquitetura SOLID

A integração com o Asaas segue os princípios SOLID:

### 7.1 Single Responsibility Principle (SRP)
- `AsaasClient` — apenas comunicação HTTP com a API Asaas (Faraday)
- `AsaasCustomerService` — apenas criação/atualização de customers
- `AsaasSubscriptionService` — apenas criação/atualização/cancelamento de assinaturas
- `AsaasWebhookProcessor` — apenas processamento lógico de eventos
- `AsaasWebhookJob` — apenas orquestração assíncrona (enfileirar + delegar)
- `Webhooks::AsaasController` — apenas接收 e validação HMAC da requisição

### 7.2 Open/Closed Principle (OCP)
- `AsaasWebhookProcessor` usa pattern Strategy: cada tipo de evento tem um handler próprio (`Handlers::Activated`, `Handlers::PaymentReceived`, `Handlers::Overdue`, `Handlers::Cancelled`)
- Novos eventos = novo handler, sem modificar código existente
- `AsaasClient` é extensível via middleware Faraday (logging, retry, cache)

### 7.3 Liskov Substitution Principle (LSP)
- Todos os handlers de webhook herdam de `AsaasWebhookHandler::Base` e são intercambiáveis
- `AsaasClient` pode ser substituído por um mock/stub em testes sem quebrar o contrato

### 7.4 Interface Segregation Principle (ISP)
- `AsaasClient` expõe apenas métodos usados: `create_customer`, `create_subscription`, `cancel_subscription`, `get_subscription`
- Services não dependem de métodos que não usam
- Controllers não conhecem detalhes da API Asaas

### 7.5 Dependency Inversion Principle (DIP)
- Services dependem de abstrações (interfaces/módulos), não de implementações concretas
- `AsaasSubscriptionService` recebe `AsaasClient` via injeção de dependência (construtor)
- Em testes, injeta `AsaasClient::Mock` ou `AsaasClient::Stub`
- Rails credentials resolvidos via `AsaasConfig` (módulo puro), não hardcoded

---

## 8. Plano de Execução (Fases)

### **Fase 1: Fundação Asaas & Customer**
- Gem `asaas` (ou HTTParty/Faraday direto)
- `AsaasClient` service (wrapper API)
- `AsaasCustomer` sync (cria/atualiza customer no Asaas quando host cadastra email/telefone)
- Credentials setup (sandbox/production)

### **Fase 2: Checkout & Subscription Creation**
- `SubscriptionsController` (`new`, `create`, `confirm`)
- `AsaasSubscriptionService` (create/update/cancel no Asaas)
- Frontend: iframe/JS Asaas + tokenização cartão
- `Subscription` sync com `asaas_*` fields

### **Fase 3: Webhooks & Ciclo de Vida**
- `Webhooks::AsaasController` + HMAC validation
- `AsaasWebhookEvent` model + idempotência
- Jobs para cada evento (activated, payment_received, overdue, cancelled)
- Atualização automática de `Subscription.status`, `current_period_end`

### **Fase 4: Host UI & Admin**
- `/account/subscription` page (plano atual, checkout, cancelar)
- Admin: detalhes Asaas no host, reprocessar webhook
- Notificações: email host quando `past_due` / `cancelled`

### **Fase 5: Testes & Hardening**
- Request specs: checkout flow, webhook processing, idempotência
- System spec: jornada completa trial → checkout → ativa
- Impeccable audit na página de assinatura
- Testes de idempotência webhook (duplicatas, retry)

---

## 8. Critérios de Aceite

1. ✅ Host em trial clica "Assinar" → escolhe plano/ciclo → checkout Asaas no site → cartão tokenizado → assinatura ativa
2. ✅ Webhook `SUBSCRIPTION_ACTIVATED` → `Subscription.status = active`, `current_period_end` preenchido
3. ✅ Webhook `SUBSCRIPTION_PAYMENT_RECEIVED` → renova `current_period_end`, mantém `active`
4. ✅ Webhook `SUBSCRIPTION_PAYMENT_OVERDUE` → `status = past_due`, email host
5. ✅ Webhook `SUBSCRIPTION_CANCELLED` → `status = cancelled`, acesso bloqueado
5. ✅ Idempotência: reenviar mesmo webhook 10x → processa 1x apenas
6. ✅ Retry: webhook falha 5x → dead letter + alerta Admin
7. ✅ Host cancela em `/account/subscription` → cancela no Asaas + `status = cancelled`
8. ✅ Admin vê `asaas_id`, `asaas_customer_id`, último webhook, pode reprocessar
9. ✅ Credentials Asaas via `ENV.fetch('ASAAS_API_KEY')` / `ENV.fetch('ASAAS_WEBHOOK_SECRET')` — falha explícita se ausentes; servidor define por ambiente
10. ✅ Arquitetura SOLID aplicada (SRP, OCP, LSP, ISP, DIP)
11. ✅ Testes: 100% request specs cobrindo fluxos + idempotência + retry

---

## 9. Dependências & Gems

| Gem | Versão | Uso |
|-----|--------|-----|
| `faraday` | latest | HTTP client Asaas API (middleware: retry, logging, json) |
| `solid_queue` | built-in | Jobs assíncronos webhooks |
| `rack-attack` | existing | Rate limit webhook endpoint |

---

## 10. Riscos & Mitigações

| Risco | Mitigação |
|-------|-----------|
| Asaas API muda | Wrapper `AsaasClient` versionado, testes de contrato |
| Webhook duplicado | Idempotência via `asaas_event_id` unique index |
| Cartão recusado | Webhook `overdue` → past_due → notifica host |
| Host cancela no Asaas direto | Webhook `CANCELLED` sincroniza status |
| PCI Compliance | iframe Asaas.js (SAQ-A), nunca toca PAN no backend |

---

## 10. Próximos Passos

1. ✅ Aprovação desta spec
2. 🔄 **Fase 1:** Implementar `AsaasClient`, `AsaasCustomer`, credentials
3. 🔄 **Fase 2:** Checkout + criação de assinatura
4. 🔄 **Fase 3:** Webhooks + jobs
5. 🔄 **Fase 4:** UI Host + Admin
6. 🔄 **Fase 5:** Testes + Auditoria

---

**Pronto para iniciar?** Se aprovado, começo pela **Fase 1** (AsaasClient, Customer sync, credentials).