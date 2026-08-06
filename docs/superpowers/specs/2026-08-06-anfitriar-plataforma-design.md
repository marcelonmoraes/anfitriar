# Anfitriar — Design da plataforma e spec do Subprojeto 1

**Data:** 2026-08-06
**Status:** aprovado no brainstorm (sessão de 2026-08-06)
**Escopo deste doc:** visão consolidada da plataforma (decisões de produto e arquitetura) + spec detalhada do Subprojeto 1 (Fundação + domínio do anfitrião). Os subprojetos 2–4 terão specs próprias.

## 1. Visão do produto

Anfitriar é um SaaS para anfitriões do Airbnb (inicialmente) criarem uma visualização
digital moderna de cada hospedagem. Quando o hóspede confirma a reserva, o anfitrião
cadastra os dados dele na plataforma e gera um link de acesso. O link abre um guia
elegante em cards por tópico (Wi-Fi, check-in/check-out, telefones úteis, restaurantes
etc.), com conteúdo pré-cadastrado pelo anfitrião.

Modelo de negócio: assinatura mensal/trimestral/semestral/anual, cobrada via Asaas
(API de assinaturas, checkout no próprio site — sem links de pagamento do Asaas).
Estratégia de preço: **volume** — entrada barata, upgrade natural para quem tem mais
imóveis.

## 2. Decisões de produto (aprovadas)

### 2.1 Planos

Dois planos, diferenciados por limite de hospedagens + recursos premium. Planos são
**dados, não código**: nome, preços por ciclo, limite e flags de recurso editáveis no
Admin, sem deploy. Valores abaixo são o ponto de partida.

| | Essencial | Pro |
|---|---|---|
| Hospedagens | até 3 | ilimitadas |
| Guias para hóspedes | ilimitados | ilimitados |
| Categorias próprias | sim | sim |
| Personalização do guia (logo, cores) | — | futuro |
| IA para gerar guia a partir do link do anúncio | — | futuro |
| Preço mensal | R$ 19,90 | R$ 39,90 |

Descontos por ciclo: trimestral −10%, semestral −15%, anual −25%.
Trial: 7 dias, sem cartão. Dias de trial configuráveis na plataforma.

Racional: o nº de hospedagens separa o anfitrião casual do profissional; categorias
próprias ficam em ambos os planos por serem o coração do produto.

### 2.2 Acesso do hóspede

- O acesso nasce de uma **Reserva** (cliente + hospedagem + check-in/check-out).
- O link `/g/:token` expira sozinho após o check-out + margem configurável (padrão 2 dias).
- Ao abrir o link, o hóspede confirma **CPF + 4 últimos dígitos do telefone**
  cadastrados pelo anfitrião. Conferiu → guia abre e um cookie assinado (escopado à
  reserva) evita nova confirmação até o fim da janela.
- O anfitrião pode revogar ou regenerar o link a qualquer momento.
- Consequência: CPF e telefone são **obrigatórios** no cadastro de cliente.

### 2.3 Categorias

- **Padrão do sistema**: sem descrição, o anfitrião não exclui; a lista é gerenciada
  pelo Owner no Admin. Lista inicial (11): Wi-Fi · Check-in/Check-out · Como chegar ·
  Regras da casa · Manual da casa · Telefones úteis · Emergências · Restaurantes ·
  Mercados e farmácias · Passeios e atrações · Transporte.
- **Próprias**: pertencem à conta do anfitrião (reusáveis em todas as hospedagens dele).
- A **descrição é sempre por hospedagem** (card). Card sem descrição ou oculto não
  aparece no guia. O anfitrião ordena e oculta categorias por hospedagem (ocultar ≠
  excluir).

### 2.4 Admin (Owner)

- Assinaturas **manuais** até o Subprojeto 4: o Owner registra plano/ciclo/pagamento
  de cada anfitrião; o dashboard financeiro (MRR, receita por período, projeções)
  calcula sobre esses registros. O Asaas passará a alimentar os mesmos registros.
- Analytics por conta **sem conteúdo**: nº de hospedagens, clientes, reservas e guias
  ativos, último acesso do anfitrião, % de preenchimento dos guias. Nunca o texto dos
  cards nem dados de hóspedes.
- Visão agregada: anfitriões ativos/trial/inadimplentes, crescimento mês a mês.

### 2.5 Idioma

MVP 100% PT-BR (interface e conteúdo). Tradução automática do conteúdo é feature
futura (candidata ao Pro). O CPF como credencial de acesso já pressupõe hóspede
brasileiro no MVP.

## 3. Arquitetura (aprovada: monolito, 3 contextos)

Um único app Rails 8.1 (Postgres, Hotwire, Tailwind, Solid Queue/Cache/Cable,
Propshaft, importmap) com três áreas separadas por namespace e autenticação:

| Contexto | Rota | Autenticação |
|---|---|---|
| Área do anfitrião | raiz autenticada | `Host` + sessão em banco |
| Admin | `/admin` | `Owner` + sessão em banco (identidade separada) |
| Guia do hóspede | `/g/:token` (público) | token + confirmação CPF/4 dígitos + cookie assinado |

- Autenticação com o generator nativo do Rails 8 (`has_secure_password`), **sem Devise**.
- Tenancy por escopo de linha (`Current.host.properties…`), sem subdomínio/slug.
- Server-rendered com Turbo/Stimulus; JavaScript mínimo.
- Código em **inglês**, interface em **português**.

## 4. Modelo de domínio

| Conceito (UI) | Model |
|---|---|
| Anfitrião | `Host` |
| Hospedagem | `Property` |
| Cliente | `Guest` |
| Reserva | `Booking` |
| Categoria | `Category` |
| Card | `Card` |
| Admin | `Owner` |
| Plano | `Plan` |
| Assinatura | `Subscription` |

```
Host: name, email_address, password_digest, phone
 ├── has_many :properties
 ├── has_many :guests
 ├── has_many :categories (próprias)
 ├── has_many :sessions
 └── has_one  :subscription

Property: host, name, address, foto de capa (Active Storage)
 └── has_many :cards

Guest: host, name, cpf (criptografado, determinístico), phone (criptografado),
       email (opcional)

Category: name, position; host_id NULL = padrão do sistema

Card: property, category, description (Action Text), position, hidden (boolean)
 — unicidade por (property, category)

Booking: property, guest, check_in, check_out, access_token (has_secure_token)
 — janela de acesso: até check_out + margem da plataforma
 — revogação: campo revoked_at; regenerar troca o token

Plan: name, prices por ciclo (mensal/trimestral/semestral/anual, em centavos),
      max_properties (NULL = ilimitado), flags de recurso

Subscription: host, plan, ciclo, status (trial/active/past_due/canceled),
      registrada manualmente pelo Owner até o Subprojeto 4

Owner: identidade separada de Host (email, senha, sessões próprias)

PlatformConfiguration (singleton): trial_days (padrão 7), booking_access_margin_days
      (padrão 2) — apenas esses dois campos no Subprojeto 1; cresce conforme surgirem
      configurações reais
```

Regras garantidas pelo domínio:

- Criar `Property` respeita `plan.max_properties` do anfitrião.
- Categoria padrão não expõe `destroy` ao anfitrião; excluir categoria própria remove
  os cards dela.
- `Guest.cpf` validado (dígitos verificadores) e único por anfitrião; exibido mascarado.
- Excluir `Guest` remove os dados de verdade (sem soft-delete de PII).

## 5. Subprojeto 1 — Fundação + domínio do anfitrião (spec)

### 5.1 Escopo

- Autenticação do `Host`: cadastro público (nome, e-mail, senha, telefone), login,
  logout, recuperação de senha. Sem confirmação de e-mail no MVP. Trial de 7 dias
  inicia no cadastro (registro `Subscription` com status trial e plano padrão de trial —
  Pro, para o anfitrião experimentar tudo).
- CRUD de hospedagens (nome, endereço, foto de capa), com limite do plano.
- Tela **Montar o guia**: por hospedagem, todas as categorias (padrão + próprias) com
  editor Action Text por card, arrastar para reordenar, alternar ocultar, indicador de
  completude ("7 de 11 preenchidas").
- CRUD de clientes (nome, CPF, telefone, e-mail opcional) com validação e máscara de CPF.
- CRUD de categorias próprias; padrão exibidas como referência (sem editar/excluir).
- Reservas: criar (hospedagem + cliente + datas) → link gerado na hora, botões copiar
  e WhatsApp (wa.me pré-preenchido); revogar/regenerar; listas de ativas/futuras e
  encerradas.
- Preview "ver como hóspede" (sem confirmação de CPF): placeholder bruto dos cards
  visíveis — o visual final é o Subprojeto 3.
- Seeds: 11 categorias padrão; planos Essencial e Pro com os valores da §2.1.
- Conta: dados do anfitrião + plano/status do trial.

### 5.2 Fora de escopo do Subprojeto 1

Admin (Subprojeto 2), guia visual + verificação do hóspede (Subprojeto 3), Asaas
(Subprojeto 4), e todo o §8.

### 5.3 Segurança e dados (desde o Subprojeto 1)

- `Guest.cpf` e `Guest.phone` com Active Record Encryption (CPF determinístico para
  unicidade/busca; telefone não-determinístico).
- CPF, telefone e tokens nos filtros de log (`filter_parameters`).
- CSP e headers de segurança ativos; Brakeman + bundler-audit no CI.
- `Booking.access_token` via `has_secure_token` (não-adivinhável).
- Autorização por escopo: todo acesso do anfitrião passa por `Current.host` — nunca
  lookup global por id.
- LGPD: plataforma armazena PII de hóspede cifrada e exibe mascarada; quem coleta é o
  anfitrião.

### 5.4 Tratamento de erros

- Validações com mensagens amigáveis em PT-BR nos formulários (inline, sem alert).
- Limite do plano atingido → tela oferece upgrade ("fale comigo" no pré-Asaas).
- Link revogado/expirado (quando o guia existir) → página neutra, sem vazar dados.

### 5.5 Testes e CI

- RSpec + FactoryBot. Model specs (limite do plano, janela da reserva, validação de
  CPF, regras de categoria/card), request specs (isolamento entre anfitriões,
  autenticação por contexto), system specs (montar o guia; criar reserva e obter link).
- GitHub Actions: RuboCop (omakase) + Brakeman + bundler-audit + RSpec como gate de
  merge. Branches + PRs desde o primeiro commit.

## 6. Roteiro dos subprojetos

1. **Fundação + domínio do anfitrião** — este doc, §5.
2. **Admin** — auth Owner, CRUD de planos e categorias padrão, gestão de anfitriões,
   assinaturas manuais, analytics de contas, dashboard financeiro (MRR, receita,
   projeções).
3. **Guia do hóspede** — visual elegante em cards, confirmação CPF + 4 dígitos, cookie
   por reserva, rate limiting na verificação, páginas de link inválido/expirado.
4. **Assinaturas Asaas** — checkout no site via API de assinaturas, webhooks, ciclo de
   vida (trial → ativa → inadimplente → bloqueio), chave da API em credentials por
   ambiente (nunca no banco — decisão herdada da iteração anterior e mantida).

## 7. Decisões herdadas da iteração anterior (repo `anfitriar` arquivado)

- Chave do Asaas em credentials por ambiente, fail-closed (ADR da iteração anterior).
- PII com Active Record Encryption + redação em logs (ADR-006 da iteração anterior).
- Autenticação nativa Rails com identidades/sessões separadas por contexto.
- CI com RSpec no gate de merge.
- O modelo de `TransactionFee` (taxa por transação) **não** se aplica — o modelo de
  negócio agora é assinatura.

## 8. Futuro registrado (fora de qualquer subprojeto atual)

IA para gerar o guia a partir do link do anúncio (Pro) · tradução automática do
conteúdo (Pro) · personalização visual do guia — logo/cores (Pro) · multi-usuário por
conta · app mobile · grandfathering de preço em mudanças de plano.
