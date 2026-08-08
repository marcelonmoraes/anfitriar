# Subprojeto 2 — Painel Administrativo (Admin / Owner)

**Data:** 2026-08-07  
**Status:** Aprovado  
**Escopo:** Implementação da área administrativa `/admin` da plataforma Anfitriar para gestão pelo Owner (Admin).

---

## 1. Visão Geral

O Subprojeto 2 introduz o contexto administrativo da plataforma, acessível em `/admin`. Ele é utilizado exclusivamente pela equipe do Anfitriar (Owner) para:
- Gerenciar planos de assinatura e valores (dados no banco, sem deploy)
- Gerenciar a lista global de categorias padrão do sistema
- Visualizar a lista de anfitriões cadastrados com analytics de conta (sem acesso ao conteúdo dos guias nem PII de hóspedes)
- Registrar e gerenciar assinaturas manuais dos anfitriões
- Acompanhar o dashboard financeiro (MRR, receita por ciclo, distribuição de status)
- Editar configurações globais da plataforma (`PlatformConfiguration`)

---

## 2. Decisões de Arquitetura & Segurança

### 2.1 Identidade Separada (`Owner`)
- O administrador é representado pelo model `Owner` (email, `password_digest`, nome).
- Não se mistura com `Host`. Um `Host` e um `Owner` são entidades distintas no banco.
- Autenticação nativa Rails (`has_secure_password`).
- Controller base: `Admin::ApplicationController` com callback `before_action :authenticate_owner!`.
- Sessão mantida via cookie assinado/criptografado específico (`:owner_session_id` ou via model `Session`/`Current.owner`).

### 2.2 Namespace de Rotas
Todas as rotas vivem sob o namespace `/admin`:
- `/admin/login` -> `Admin::SessionsController#new` / `#create`
- `/admin/logout` -> `Admin::SessionsController#destroy`
- `/admin` -> `Admin::DashboardController#show`
- `/admin/plans` -> `Admin::PlansController` (CRUD)
- `/admin/categories` -> `Admin::CategoriesController` (CRUD de categorias padrão: `host_id IS NULL`)
- `/admin/hosts` -> `Admin::HostsController` (Index, Show)
- `/admin/hosts/:host_id/subscription` -> `Admin::SubscriptionsController` (Edit, Update)
- `/admin/platform_configuration` -> `Admin::PlatformConfigurationsController` (Edit, Update)

### 2.3 Privacidade de Dados (LGPD & Analytics Sem Conteúdo)
Conforme spec original §2.4:
- O Admin **nunca** visualiza o conteúdo digitado nos cards dos guias.
- O Admin **nunca** visualiza CPF, telefone ou nome dos hóspedes dos anfitriões.
- Analytics exibidos por anfitrião:
  - Quantidade de hospedagens cadastradas
  - Quantidade de clientes cadastrados (apenas contador)
  - Quantidade de reservas ativas / encerradas
  - Porcentagem média de preenchimento dos guias (% cards preenchidos / categorias disponíveis)
  - Data do último acesso / criação da conta

---

## 3. Modelo de Domínio

### 3.1 Novos Models / Alterações

#### `Owner`
- `name` (string, presence: true)
- `email_address` (string, presence: true, unique, normalizes downcase)
- `password_digest` (string, presence: true)

#### `Subscription` (Refinamento para controle manual)
- `host_id` (belongs_to)
- `plan_id` (belongs_to)
- `billing_cycle` (string: `"monthly"`, `"quarterly"`, `"semiannual"`, `"annual"`)
- `status` (string: `"trial"`, `"active"`, `"past_due"`, `"canceled"`)
- `trial_ends_at` (datetime)
- Método helper `#mrr_cents`: calcula o valor mensal equivalente com base no plano e no ciclo de cobrança.

---

## 4. Métricas Financeiras (Dashboard)

### 4.1 MRR (Monthly Recurring Revenue)
Cálculo de receita mensal recorrente ponderada por ciclo para assinaturas com status `active`:
- **Mensal:** `plan.monthly_price_cents`
- **Trimestral:** `plan.quarterly_price_cents / 3`
- **Semestral:** `plan.semiannual_price_cents / 6`
- **Anual:** `plan.annual_price_cents / 12`

### 4.2 Indicadores Agregados
- **Total de Anfitriões:** Ativos / Trial / Inadimplentes (`past_due`) / Cancelados
- **MRR Total:** Valor formatado em R$
- **ARR Projetado:** `MRR * 12`
- **Taxa de Conversão de Trial:** % de anfitriões que migraram de `trial` para `active`

---

## 5. Interface do Admin (Design System)

Alinhada estritamente com `DESIGN.md`:
- Fundo `#f9fafb`, cards brancos com borda `1px #e5e7eb`
- Tom de acento: Charcoal `#111827`
- Layout de coluna única centralizado ou container estendido `max-w-6xl` para o dashboard
- Navigation bar dedicada para o Admin com indicador `/admin`

---

## 6. Plano de Execução (Fases)

### **Fase 1: Fundação Admin & Autenticação Owner**
- Migration e Model `Owner` + Factory + Spec
- `Admin::ApplicationController` + `Admin::SessionsController` (Login/Logout)
- Views de login do admin + Layout de navegação Admin
- Seed de um `Owner` padrão em desenvolvimento (`admin@anfitriar.com.br`)

### **Fase 2: Dashboard & Módulos Principais**
- `Admin::DashboardController`: visualização de MRR, contadores agregados e métricas
- `Admin::PlansController`: CRUD completo de planos (valores em centavos, limites de imóveis)
- `Admin::CategoriesController`: CRUD de categorias padrão do sistema (`host_id IS NULL`)

### **Fase 3: Gestão de Anfitriões & Assinaturas Manuais**
- `Admin::HostsController`: listagem com filtros (status, plano), busca por nome/email e visualização de analytics de conta (sem conteúdo)
- `Admin::SubscriptionsController`: atualização manual de plano, ciclo, status e renovação de trial
- `Admin::PlatformConfigurationsController`: ajuste de dias de trial (padrão 7) e margem de acesso (padrão 2 dias)

### **Fase 4: Testes & Auditoria**
- Model specs (`Owner`, cálculos de MRR)
- Request specs para todas as rotas `/admin` (garantindo isolamento — Host não acessa Admin, unauthenticated redireciona para login do Admin)
- Impeccable Audit/Polish na interface do Admin

---

## 7. Critérios de Aceite
1. Rota `/admin` é inacessível para usuários não autenticados como `Owner` (redireciona para `/admin/login`).
2. Anfitriões comunss (`Host`) não conseguem acessar rotas `/admin` mesmo logados.
3. Owner consegue criar, editar e atualizar planos e valores por ciclo.
4. Owner consegue adicionar, reordenar e excluir categorias padrão do sistema.
5. Owner consegue visualizar anfitriões e alterar o status da assinatura manualmente.
6. O cálculo de MRR no Dashboard reflete corretamente as assinaturas ativas e seus ciclos.
7. Nenhuma informação privada de hóspedes (CPF, telefone) ou conteúdo dos cards é exposta no Admin.
8. Testes automatizados cobrindo 100% das novas controllers e regras de negócio.
