# Subprojeto 1 — Fundação + Domínio do Anfitrião — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Entregar a área autenticada do anfitrião: conta com trial, CRUDs de hospedagens/clientes/categorias, montagem do guia por cards e reservas com link de acesso.

**Architecture:** Monolito Rails 8.1 (spec §3): contexto do anfitrião na raiz autenticada, autenticação nativa (`has_secure_password` + sessões em banco, sem Devise), tenancy por escopo de linha via `Current.host`. Rota pública `/g/:token` existe apenas como placeholder neutro (guia real é o Subprojeto 3).

**Tech Stack:** Rails 8.1.3.1 · Ruby 4.0.5 · Postgres · Hotwire (Turbo/Stimulus) · Tailwind · Action Text (Trix) · Active Storage · RSpec + FactoryBot · GitHub Actions

**Spec:** `docs/superpowers/specs/2026-08-06-anfitriar-plataforma-design.md` (§4 domínio, §5 escopo)

## Global Constraints

- Código em **inglês**, interface em **português** (pt-BR). `config.i18n.default_locale = :"pt-BR"`, `config.time_zone = "America/Sao_Paulo"`.
- Dinheiro sempre em **centavos inteiros** (`*_price_cents`).
- Valores da spec, verbatim: trial **7 dias**; margem de acesso pós-check-out **2 dias**; Essencial `max_properties: 3`, mensal **1990** centavos; Pro `max_properties: NULL`, mensal **3990** centavos; descontos trimestral −10%, semestral −15%, anual −25%.
- 11 categorias padrão, nesta ordem: Wi-Fi · Check-in/Check-out · Como chegar · Regras da casa · Manual da casa · Telefones úteis · Emergências · Restaurantes · Mercados e farmácias · Passeios e atrações · Transporte.
- PII: `Guest.cpf` criptografado **determinístico**, `Guest.phone` criptografado **não-determinístico**; `cpf`, `phone`, `token`, `access_token` nos filtros de log; CPF exibido sempre mascarado (`***.XXX.XXX-**`).
- Todo controller do contexto anfitrião escopa por `Current.host.…` — **nunca** lookup global (`Model.find`) de registro de outro dono.
- Cada task termina com `bundle exec rspec` verde **e** `bin/rubocop` sem ofensas antes do commit. Commits convencionais em português, **sem trailers** (sem Co-Authored-By, sem "Generated with", sem Claude-Session).
- Trabalho na branch `feat/subprojeto-1-fundacao` (criada na Task 1). **Não fazer push**: o remote ainda não foi definido pelo usuário (o repo GitHub `anfitriar` contém a iteração anterior, incompatível com este histórico).
- Requisito local: Postgres acessível com as configs padrão de `config/database.yml` (`bin/rails db:prepare` funciona). Se não houver, pare e avise o usuário — não improvise SQLite.
- **UI/layout: invocar a skill `impeccable` antes de escrever views.** Vale para as tasks que criam layout ou telas (Tasks 3, 4, 7, 8, 9, 11, 13, 14, 15). Os snippets ERB deste plano definem a **estrutura e os dados** de cada tela (campos, botões, estados); a skill governa o refinamento visual (hierarquia, espaçamento, estados vazios, consistência). Não inventar conteúdo além do especificado — refinar a apresentação do que está aqui.

## Estrutura de arquivos (visão geral)

```
app/models/           current.rb, host.rb, session.rb, platform_configuration.rb,
                      plan.rb, subscription.rb, category.rb, property.rb, guest.rb,
                      card.rb, booking.rb
app/validators/       cpf_validator.rb
app/controllers/      concerns/authentication.rb, sessions_controller.rb,
                      registrations_controller.rb, passwords_controller.rb,
                      properties_controller.rb, guests_controller.rb,
                      categories_controller.rb, bookings_controller.rb,
                      accounts_controller.rb, public_guides_controller.rb,
                      home_controller.rb (temporário, morre na Task 7),
                      properties/guides_controller.rb, properties/guide_cards_controller.rb,
                      properties/guide_reorders_controller.rb, properties/previews_controller.rb
app/helpers/          bookings_helper.rb, subscriptions_helper.rb
app/mailers/          passwords_mailer.rb
app/javascript/controllers/  clipboard_controller.js, sortable_controller.js
app/views/            layouts (nav, flash), sessions, registrations, passwords,
                      properties (+ guides, previews), guests, categories, bookings,
                      accounts, public_guides, shared/_form_errors
spec/                 espelha app/ (models, requests, system, factories, support)
.github/workflows/ci.yml   db/seeds.rb   config/locales/pt-BR.yml
```

Cada task produz um deliverable testável e commitado. As tasks devem ser executadas em ordem (dependências de migração e de rotas).

---

### Task 1: Fundação de testes, i18n, criptografia, CSP e CI

**Files:**
- Modify: `Gemfile`
- Create: `spec/rails_helper.rb`, `spec/spec_helper.rb` (via generator), `spec/support/authentication_helpers.rb`, `spec/config/platform_defaults_spec.rb`
- Create: `config/locales/pt-BR.yml`, `config/initializers/content_security_policy.rb` (substituir comentado)
- Modify: `config/application.rb`, `config/environments/development.rb`, `config/environments/test.rb`, `config/initializers/filter_parameter_logger.rb`, `.github/workflows/ci.yml`

**Interfaces:**
- Consumes: esqueleto Rails 8.1 já commitado (`124fad3`).
- Produces: `sign_in(host, password:)` helper para request specs; `rspec` e `rubocop` funcionando; locale/timezone; chaves de AR Encryption em dev/test; CI com gate de RSpec.

- [ ] **Step 1: Criar a branch**

```bash
git checkout -b feat/subprojeto-1-fundacao
```

- [ ] **Step 2: Adicionar gems e instalar**

No `Gemfile`, adicionar ao grupo `:development, :test` (junto de `debug`):

```ruby
gem "rspec-rails"
gem "factory_bot_rails"
```

E na seção principal (fora de grupos), logo após `gem "image_processing", "~> 1.2"`:

```ruby
# Traduções pt-BR para Active Record, Action View etc.
gem "rails-i18n", "~> 8.0"
```

Rodar:

```bash
bundle install
bin/rails generate rspec:install
bin/rails db:prepare
```

- [ ] **Step 3: Configurar RSpec + FactoryBot + helper de login**

Em `spec/rails_helper.rb`, dentro do `RSpec.configure do |config|`, adicionar:

```ruby
config.include FactoryBot::Syntax::Methods

config.before(:each, type: :system) do
  driven_by :rack_test
end
```

E, acima do bloco `RSpec.configure`, depois dos requires existentes:

```ruby
Rails.root.glob("spec/support/**/*.rb").sort.each { |f| require f }
```

Criar `spec/support/authentication_helpers.rb`:

```ruby
module AuthenticationHelpers
  def sign_in(host, password: "senha-segura-123")
    post session_path, params: { email_address: host.email_address, password: password }
  end
end

RSpec.configure do |config|
  config.include AuthenticationHelpers, type: :request
end
```

(O helper referencia `session_path`, que nasce na Task 3 — nenhum spec o usa antes disso.)

- [ ] **Step 4: Escrever o spec de configuração (falhando)**

Criar `spec/config/platform_defaults_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe "Configuração da plataforma" do
  it "usa pt-BR como locale padrão" do
    expect(I18n.default_locale).to eq(:"pt-BR")
  end

  it "usa o fuso de São Paulo" do
    expect(Rails.application.config.time_zone).to eq("America/Sao_Paulo")
  end

  it "filtra PII e tokens dos logs" do
    filters = Rails.application.config.filter_parameters
    %i[cpf phone token access_token].each do |key|
      expect(filters).to include(key), "esperava #{key} nos filter_parameters"
    end
  end
end
```

- [ ] **Step 5: Rodar e ver falhar**

Run: `bundle exec rspec spec/config/platform_defaults_spec.rb`
Expected: FAIL (locale `:en`, filtros ausentes)

- [ ] **Step 6: Configurar aplicação**

Em `config/application.rb`, dentro da classe `Application`, adicionar:

```ruby
config.time_zone = "America/Sao_Paulo"
config.i18n.default_locale = :"pt-BR"
config.i18n.available_locales = [ :"pt-BR", :en ]
```

Em `config/initializers/filter_parameter_logger.rb`, garantir:

```ruby
Rails.application.config.filter_parameters += [
  :passw, :email, :secret, :token, :_key, :crypt, :salt, :certificate, :otp, :ssn, :cvv, :cvc,
  :cpf, :phone, :access_token
]
```

Criar `config/locales/pt-BR.yml`:

```yaml
pt-BR:
  nav:
    properties: "Hospedagens"
    guests: "Clientes"
    bookings: "Reservas"
    categories: "Categorias"
    account: "Conta"
    logout: "Sair"
  activerecord:
    models:
      host: "Anfitrião"
      property: "Hospedagem"
      guest: "Cliente"
      booking: "Reserva"
      category: "Categoria"
      card: "Card"
      plan: "Plano"
      subscription: "Assinatura"
    attributes:
      host:
        name: "Nome"
        email_address: "E-mail"
        phone: "Telefone"
        password: "Senha"
        password_confirmation: "Confirmação de senha"
      property:
        name: "Nome"
        address: "Endereço"
        cover_photo: "Foto de capa"
      guest:
        name: "Nome"
        cpf: "CPF"
        phone: "Telefone"
        email: "E-mail"
      booking:
        property: "Hospedagem"
        guest: "Cliente"
        check_in: "Check-in"
        check_out: "Check-out"
      category:
        name: "Nome"
```

- [ ] **Step 7: Chaves de Active Record Encryption (dev/test)**

Em `config/environments/development.rb` e `config/environments/test.rb`, dentro do bloco `configure`, adicionar (chaves estáticas locais — produção usará credentials, tarefa do deploy, fora deste plano):

```ruby
# Chaves locais de Active Record Encryption (produção usa credentials).
config.active_record.encryption.primary_key = "dev-test-primary-key-0000000000000"
config.active_record.encryption.deterministic_key = "dev-test-deterministic-key-000000"
config.active_record.encryption.key_derivation_salt = "dev-test-derivation-salt-00000000"
```

- [ ] **Step 8: CSP**

Substituir o conteúdo de `config/initializers/content_security_policy.rb` por:

```ruby
Rails.application.configure do
  config.content_security_policy do |policy|
    policy.default_src :self
    policy.font_src    :self, :data
    policy.img_src     :self, :data, :blob
    policy.object_src  :none
    policy.script_src  :self
    policy.style_src   :self
    policy.frame_ancestors :none
    policy.base_uri    :self
    policy.form_action :self
  end

  config.content_security_policy_nonce_generator = ->(request) { request.session.id.to_s }
  config.content_security_policy_nonce_directives = %w[script-src]
end
```

- [ ] **Step 9: CI com RSpec no gate**

Substituir `.github/workflows/ci.yml` por:

```yaml
name: CI

on:
  pull_request:
  push:
    branches: [ main ]

jobs:
  scan_ruby:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: ruby/setup-ruby@v1
        with:
          ruby-version: .ruby-version
          bundler-cache: true
      - name: Brakeman
        run: bin/brakeman --no-pager
      - name: bundler-audit
        run: bundle exec bundler-audit check --update

  lint:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: ruby/setup-ruby@v1
        with:
          ruby-version: .ruby-version
          bundler-cache: true
      - name: RuboCop
        run: bin/rubocop -f github

  test:
    runs-on: ubuntu-latest
    services:
      postgres:
        image: postgres:17
        env:
          POSTGRES_USER: postgres
          POSTGRES_PASSWORD: postgres
        ports: [ "5432:5432" ]
        options: >-
          --health-cmd="pg_isready"
          --health-interval=10s
          --health-timeout=5s
          --health-retries=3
    env:
      RAILS_ENV: test
      DATABASE_URL: postgres://postgres:postgres@localhost:5432/anfitriar_test
    steps:
      - uses: actions/checkout@v4
      - uses: ruby/setup-ruby@v1
        with:
          ruby-version: .ruby-version
          bundler-cache: true
      - name: Preparar banco
        run: bin/rails db:test:prepare
      - name: Compilar Tailwind
        run: bin/rails tailwindcss:build
      - name: RSpec
        run: bundle exec rspec
```

(Nota para o usuário, não para o executor: o "gate de merge" se completa ativando branch protection no GitHub quando houver remote.)

- [ ] **Step 10: Rodar tudo e ver passar**

Run: `bundle exec rspec && bin/rubocop`
Expected: specs de configuração PASS; RuboCop sem ofensas (se o generator do RSpec gerar arquivos com ofensas de estilo, rodar `bin/rubocop -a` e revisar o diff)

- [ ] **Step 11: Commit**

```bash
git add -A
git commit -m "chore: base de testes (RSpec), i18n pt-BR, criptografia, CSP e CI"
```

---

### Task 2: PlatformConfiguration e Plan com seeds

**Files:**
- Create: `db/migrate/*_create_platform_configurations.rb`, `db/migrate/*_create_plans.rb`
- Create: `app/models/platform_configuration.rb`, `app/models/plan.rb`
- Create: `spec/models/platform_configuration_spec.rb`, `spec/models/plan_spec.rb`, `spec/factories/plans.rb`
- Modify: `db/seeds.rb` (substituir conteúdo gerado)

**Interfaces:**
- Consumes: Task 1 (RSpec).
- Produces: `PlatformConfiguration.current` → registro único com `trial_days` (7) e `booking_access_margin_days` (2); `Plan` com `slug` (string, único), `name`, `monthly_price_cents`, `quarterly_price_cents`, `semiannual_price_cents`, `annual_price_cents`, `max_properties` (int, NULL = ilimitado); seeds idempotentes criam `essencial` e `pro`; factory `:plan` (com `sequence` de slug) e trait `:limited` (`max_properties: 1`).

- [ ] **Step 1: Escrever specs (falhando)**

Criar `spec/models/platform_configuration_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe PlatformConfiguration do
  describe ".current" do
    it "cria o registro único com os padrões da spec" do
      config = described_class.current
      expect(config.trial_days).to eq(7)
      expect(config.booking_access_margin_days).to eq(2)
    end

    it "reutiliza o mesmo registro em chamadas seguintes" do
      expect { 3.times { described_class.current } }.to change(described_class, :count).by(1)
    end
  end
end
```

Criar `spec/models/plan_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe Plan do
  it "exige slug e nome únicos" do
    create(:plan, slug: "essencial", name: "Essencial")
    duplicate = build(:plan, slug: "essencial", name: "Essencial")
    expect(duplicate).not_to be_valid
  end

  it "rejeita preços negativos" do
    plan = build(:plan, monthly_price_cents: -1)
    expect(plan).not_to be_valid
  end

  it "aceita max_properties nulo (ilimitado)" do
    expect(build(:plan, max_properties: nil)).to be_valid
  end

  describe "seeds" do
    it "cria Essencial e Pro com os valores da spec, de forma idempotente" do
      2.times { Rails.application.load_seed }

      expect(Plan.count).to eq(2)

      essencial = Plan.find_by!(slug: "essencial")
      expect(essencial.max_properties).to eq(3)
      expect(essencial.monthly_price_cents).to eq(1990)
      expect(essencial.quarterly_price_cents).to eq(5373)
      expect(essencial.semiannual_price_cents).to eq(10_149)
      expect(essencial.annual_price_cents).to eq(17_910)

      pro = Plan.find_by!(slug: "pro")
      expect(pro.max_properties).to be_nil
      expect(pro.monthly_price_cents).to eq(3990)
      expect(pro.quarterly_price_cents).to eq(10_773)
      expect(pro.semiannual_price_cents).to eq(20_349)
      expect(pro.annual_price_cents).to eq(35_910)
    end
  end
end
```

Criar `spec/factories/plans.rb`:

```ruby
FactoryBot.define do
  factory :plan do
    sequence(:slug) { |n| "plano-#{n}" }
    sequence(:name) { |n| "Plano #{n}" }
    monthly_price_cents { 1990 }
    quarterly_price_cents { 5373 }
    semiannual_price_cents { 10_149 }
    annual_price_cents { 17_910 }
    max_properties { nil }

    trait :limited do
      max_properties { 1 }
    end
  end
end
```

- [ ] **Step 2: Rodar e ver falhar**

Run: `bundle exec rspec spec/models`
Expected: FAIL com "uninitialized constant PlatformConfiguration" / "Plan"

- [ ] **Step 3: Migrations e models**

```bash
bin/rails generate migration CreatePlatformConfigurations
bin/rails generate migration CreatePlans
```

Migration de platform_configurations:

```ruby
class CreatePlatformConfigurations < ActiveRecord::Migration[8.1]
  def change
    create_table :platform_configurations do |t|
      t.integer :trial_days, null: false, default: 7
      t.integer :booking_access_margin_days, null: false, default: 2

      t.timestamps
    end
  end
end
```

Migration de plans:

```ruby
class CreatePlans < ActiveRecord::Migration[8.1]
  def change
    create_table :plans do |t|
      t.string :slug, null: false, index: { unique: true }
      t.string :name, null: false, index: { unique: true }
      t.integer :monthly_price_cents, null: false
      t.integer :quarterly_price_cents, null: false
      t.integer :semiannual_price_cents, null: false
      t.integer :annual_price_cents, null: false
      t.integer :max_properties

      t.timestamps
    end
  end
end
```

Criar `app/models/platform_configuration.rb`:

```ruby
class PlatformConfiguration < ApplicationRecord
  validates :trial_days, :booking_access_margin_days,
            numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  def self.current
    first_or_create!
  end
end
```

Criar `app/models/plan.rb`:

```ruby
class Plan < ApplicationRecord
  validates :slug, :name, presence: true, uniqueness: true
  validates :monthly_price_cents, :quarterly_price_cents, :semiannual_price_cents, :annual_price_cents,
            numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :max_properties, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true
end
```

Substituir `db/seeds.rb` por:

```ruby
# Planos (valores em centavos; descontos: trimestral −10%, semestral −15%, anual −25%)
[
  { slug: "essencial", name: "Essencial", monthly_price_cents: 1990,
    quarterly_price_cents: 5373, semiannual_price_cents: 10_149, annual_price_cents: 17_910,
    max_properties: 3 },
  { slug: "pro", name: "Pro", monthly_price_cents: 3990,
    quarterly_price_cents: 10_773, semiannual_price_cents: 20_349, annual_price_cents: 35_910,
    max_properties: nil }
].each do |attributes|
  plan = Plan.find_or_initialize_by(slug: attributes[:slug])
  plan.update!(attributes)
end
```

Rodar `bin/rails db:migrate`.

- [ ] **Step 4: Rodar e ver passar**

Run: `bundle exec rspec spec/models && bin/rubocop`
Expected: PASS, sem ofensas

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "feat: configuração da plataforma e planos com seeds"
```

---

### Task 3: Autenticação do anfitrião (login/logout)

**Files:**
- Create: `db/migrate/*_create_hosts.rb`, `db/migrate/*_create_sessions.rb`
- Create: `app/models/host.rb`, `app/models/session.rb`, `app/models/current.rb`
- Create: `app/controllers/concerns/authentication.rb`, `app/controllers/sessions_controller.rb`, `app/controllers/home_controller.rb` (temporário)
- Create: `app/views/sessions/new.html.erb`, `app/views/home/index.html.erb`, `app/views/layouts/_nav.html.erb`, `app/views/shared/_form_errors.html.erb`
- Modify: `Gemfile` (descomentar bcrypt), `app/controllers/application_controller.rb`, `app/views/layouts/application.html.erb`, `config/routes.rb`
- Test: `spec/models/host_spec.rb`, `spec/requests/authentication_spec.rb`, `spec/factories/hosts.rb`

**Interfaces:**
- Consumes: helper `sign_in` (Task 1).
- Produces: `Host` (`name`, `email_address`, `phone`, `has_secure_password`; `has_many :sessions`); `Session` (`belongs_to :host`, `ip_address`, `user_agent`); `Current.session` / `Current.host`; concern `Authentication` com `require_authentication` (before_action padrão), `allow_unauthenticated_access(**options)`, `authenticated?`, `start_new_session_for(host)`, `terminate_session`, `after_authentication_url`; rotas `resource :session` e `root "home#index"` (home é placeholder, substituído na Task 7); factory `:host` (senha padrão `"senha-segura-123"`); layout com nav parcial `layouts/_nav` e flashes.

- [ ] **Step 1: Descomentar bcrypt e instalar**

No `Gemfile`, descomentar a linha `gem "bcrypt", "~> 3.1.7"` e rodar `bundle install`.

- [ ] **Step 2: Escrever specs (falhando)**

Criar `spec/factories/hosts.rb`:

```ruby
FactoryBot.define do
  factory :host do
    name { "Ana Anfitriã" }
    sequence(:email_address) { |n| "ana#{n}@example.com" }
    phone { "11987654321" }
    password { "senha-segura-123" }
  end
end
```

Criar `spec/models/host_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe Host do
  it "normaliza o e-mail" do
    host = create(:host, email_address: "  Ana@Example.COM ")
    expect(host.email_address).to eq("ana@example.com")
  end

  it "normaliza o telefone para dígitos" do
    host = create(:host, phone: "(11) 98765-4321")
    expect(host.phone).to eq("11987654321")
  end

  it "exige e-mail único" do
    create(:host, email_address: "ana@example.com")
    expect(build(:host, email_address: "ana@example.com")).not_to be_valid
  end

  it "exige nome, telefone e senha" do
    host = described_class.new
    host.valid?
    expect(host.errors[:name]).to be_present
    expect(host.errors[:phone]).to be_present
    expect(host.errors[:password]).to be_present
  end

  it "rejeita telefone sem DDD" do
    expect(build(:host, phone: "987654321")).not_to be_valid
  end

  it "autentica por senha" do
    host = create(:host, password: "senha-segura-123")
    expect(host.authenticate("senha-segura-123")).to eq(host)
    expect(host.authenticate("errada")).to be_falsey
  end
end
```

Criar `spec/requests/authentication_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe "Autenticação", type: :request do
  let!(:host) { create(:host, password: "senha-segura-123") }

  it "faz login com credenciais válidas e cria sessão" do
    post session_path, params: { email_address: host.email_address, password: "senha-segura-123" }
    expect(response).to redirect_to(root_path)
    expect(host.sessions.count).to eq(1)
  end

  it "rejeita credenciais inválidas" do
    post session_path, params: { email_address: host.email_address, password: "errada" }
    expect(response).to redirect_to(new_session_path)
    expect(host.sessions.count).to eq(0)
  end

  it "exige login para a área do anfitrião" do
    get root_path
    expect(response).to redirect_to(new_session_path)
  end

  it "dá acesso após o login e encerra no logout" do
    sign_in host
    get root_path
    expect(response).to have_http_status(:ok)

    delete session_path
    expect(response).to redirect_to(new_session_path)
    expect(host.sessions.count).to eq(0)
  end
end
```

- [ ] **Step 3: Rodar e ver falhar**

Run: `bundle exec rspec spec/models/host_spec.rb spec/requests/authentication_spec.rb`
Expected: FAIL ("uninitialized constant Host" / rotas inexistentes)

- [ ] **Step 4: Migrations**

```bash
bin/rails generate migration CreateHosts
bin/rails generate migration CreateSessions
```

```ruby
class CreateHosts < ActiveRecord::Migration[8.1]
  def change
    create_table :hosts do |t|
      t.string :name, null: false
      t.string :email_address, null: false, index: { unique: true }
      t.string :phone, null: false
      t.string :password_digest, null: false

      t.timestamps
    end
  end
end
```

```ruby
class CreateSessions < ActiveRecord::Migration[8.1]
  def change
    create_table :sessions do |t|
      t.references :host, null: false, foreign_key: true
      t.string :ip_address
      t.string :user_agent

      t.timestamps
    end
  end
end
```

Rodar `bin/rails db:migrate`.

- [ ] **Step 5: Models e concern**

`app/models/host.rb`:

```ruby
class Host < ApplicationRecord
  has_secure_password
  has_many :sessions, dependent: :destroy

  normalizes :email_address, with: ->(e) { e.strip.downcase }
  normalizes :phone, with: ->(p) { p.gsub(/\D/, "") }

  validates :name, presence: true
  validates :email_address, presence: true, uniqueness: true,
            format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :phone, presence: true,
            format: { with: /\A\d{10,11}\z/, message: "deve ter DDD + número (10 ou 11 dígitos)" }
end
```

`app/models/session.rb`:

```ruby
class Session < ApplicationRecord
  belongs_to :host
end
```

`app/models/current.rb`:

```ruby
class Current < ActiveSupport::CurrentAttributes
  attribute :session
  delegate :host, to: :session, allow_nil: true
end
```

`app/controllers/concerns/authentication.rb`:

```ruby
module Authentication
  extend ActiveSupport::Concern

  included do
    before_action :require_authentication
    helper_method :authenticated?
  end

  class_methods do
    def allow_unauthenticated_access(**options)
      skip_before_action :require_authentication, **options
    end
  end

  private
    def authenticated?
      resume_session
    end

    def require_authentication
      resume_session || request_authentication
    end

    def resume_session
      Current.session ||= find_session_by_cookie
    end

    def find_session_by_cookie
      Session.find_by(id: cookies.signed[:session_id]) if cookies.signed[:session_id]
    end

    def request_authentication
      session[:return_to_after_authenticating] = request.url
      redirect_to new_session_path
    end

    def after_authentication_url
      session.delete(:return_to_after_authenticating) || root_url
    end

    def start_new_session_for(host)
      host.sessions.create!(user_agent: request.user_agent, ip_address: request.remote_ip).tap do |new_session|
        Current.session = new_session
        cookies.signed.permanent[:session_id] = { value: new_session.id, httponly: true, same_site: :lax }
      end
    end

    def terminate_session
      Current.session.destroy
      cookies.delete(:session_id)
    end
end
```

`app/controllers/application_controller.rb` (substituir):

```ruby
class ApplicationController < ActionController::Base
  include Authentication

  allow_browser versions: :modern
end
```

- [ ] **Step 6: Controllers, rotas e views**

`app/controllers/sessions_controller.rb`:

```ruby
class SessionsController < ApplicationController
  allow_unauthenticated_access only: %i[new create]
  rate_limit to: 10, within: 3.minutes, only: :create,
             with: -> { redirect_to new_session_url, alert: "Muitas tentativas. Aguarde alguns minutos." }

  def new
  end

  def create
    if host = Host.authenticate_by(email_address: params[:email_address], password: params[:password])
      start_new_session_for host
      redirect_to after_authentication_url
    else
      redirect_to new_session_path, alert: "E-mail ou senha inválidos."
    end
  end

  def destroy
    terminate_session
    redirect_to new_session_path, notice: "Você saiu da sua conta."
  end
end
```

`app/controllers/home_controller.rb` (temporário — a Task 7 remove e aponta root para properties):

```ruby
class HomeController < ApplicationController
  def index
  end
end
```

`config/routes.rb` (substituir o miolo, mantendo o health check gerado):

```ruby
Rails.application.routes.draw do
  resource :session, only: %i[new create destroy]

  root "home#index"

  get "up" => "rails/health#show", as: :rails_health_check
end
```

`app/views/home/index.html.erb`:

```erb
<h1 class="text-2xl font-bold">Bem-vindo ao Anfitriar</h1>
<p class="mt-2 text-gray-600">Sua área do anfitrião está sendo construída.</p>
```

`app/views/shared/_form_errors.html.erb`:

```erb
<% if record.errors.any? %>
  <div class="mb-4 rounded-lg bg-red-50 p-3 text-sm text-red-800">
    <ul class="list-inside list-disc">
      <% record.errors.full_messages.each do |message| %>
        <li><%= message %></li>
      <% end %>
    </ul>
  </div>
<% end %>
```

`app/views/sessions/new.html.erb`:

```erb
<div class="mx-auto mt-16 max-w-sm">
  <h1 class="mb-6 text-center text-2xl font-bold">Entrar no Anfitriar</h1>
  <%= form_with url: session_path, class: "space-y-4" do |f| %>
    <div>
      <%= f.label :email_address, "E-mail", class: "block text-sm font-medium" %>
      <%= f.email_field :email_address, required: true, autofocus: true, autocomplete: "username",
            class: "mt-1 w-full rounded-lg border-gray-300" %>
    </div>
    <div>
      <%= f.label :password, "Senha", class: "block text-sm font-medium" %>
      <%= f.password_field :password, required: true, autocomplete: "current-password",
            class: "mt-1 w-full rounded-lg border-gray-300" %>
    </div>
    <%= f.submit "Entrar", class: "w-full rounded-lg bg-gray-900 px-4 py-2 font-medium text-white" %>
  <% end %>
</div>
```

`app/views/layouts/_nav.html.erb` (links são adicionados pelas tasks seguintes conforme as telas nascem):

```erb
<nav class="border-b bg-white">
  <div class="mx-auto flex max-w-4xl items-center justify-between px-4 py-3">
    <span class="font-bold">Anfitriar</span>
    <div class="flex items-center gap-4 text-sm">
      <%= button_to t("nav.logout"), session_path, method: :delete, class: "text-gray-500 hover:text-gray-900" %>
    </div>
  </div>
</nav>
```

Em `app/views/layouts/application.html.erb`: manter o `<head>` gerado (asset tags intactos), trocar `<html>` para `<html lang="pt-BR">`, definir `<title>Anfitriar</title>` e substituir o `<body>` por:

```erb
<body class="min-h-screen bg-gray-50 text-gray-900">
  <% if authenticated? %>
    <%= render "layouts/nav" %>
  <% end %>
  <main class="mx-auto max-w-4xl px-4 py-6">
    <% if notice %><div class="mb-4 rounded-lg bg-green-50 p-3 text-sm text-green-800"><%= notice %></div><% end %>
    <% if alert %><div class="mb-4 rounded-lg bg-red-50 p-3 text-sm text-red-800"><%= alert %></div><% end %>
    <%= yield %>
  </main>
</body>
```

- [ ] **Step 7: Rodar e ver passar**

Run: `bundle exec rspec && bin/rubocop`
Expected: PASS, sem ofensas

- [ ] **Step 8: Commit**

```bash
git add -A
git commit -m "feat: autenticação do anfitrião (login/logout)"
```

---

### Task 4: Cadastro público com trial de 7 dias

**Files:**
- Create: `db/migrate/*_create_subscriptions.rb`, `app/models/subscription.rb`, `app/controllers/registrations_controller.rb`, `app/views/registrations/new.html.erb`
- Modify: `app/models/host.rb` (associação), `app/models/plan.rb` (associação), `config/routes.rb`, `app/views/sessions/new.html.erb` (link "Criar conta")
- Test: `spec/models/subscription_spec.rb`, `spec/requests/registrations_spec.rb`, `spec/factories/subscriptions.rb`

**Interfaces:**
- Consumes: `Host`, `start_new_session_for` (Task 3); `Plan` factory e seeds (Task 2); `PlatformConfiguration.current` (Task 2).
- Produces: `Subscription` (`belongs_to :host` único, `belongs_to :plan`, `status` enum string `trial/active/past_due/canceled`, `billing_cycle` enum string opcional `monthly/quarterly/semiannual/annual`, `trial_ends_at`); `Subscription.start_trial_for(host)` → cria trial no plano `pro`; `Subscription#trial_days_left` → Integer ≥ 0; `Host#subscription`; rota `resource :registration, only: %i[new create]`; factory `:subscription`.

- [ ] **Step 1: Escrever specs (falhando)**

Criar `spec/factories/subscriptions.rb`:

```ruby
FactoryBot.define do
  factory :subscription do
    host
    plan
    status { "trial" }
    trial_ends_at { 7.days.from_now }
  end
end
```

Criar `spec/models/subscription_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe Subscription do
  describe ".start_trial_for" do
    it "cria trial no plano Pro com a duração configurada" do
      pro = create(:plan, slug: "pro", name: "Pro")
      host = create(:host)

      subscription = described_class.start_trial_for(host)

      expect(subscription.plan).to eq(pro)
      expect(subscription).to be_trial
      expect(subscription.trial_ends_at.to_date).to eq(Date.current + 7)
    end
  end

  it "permite uma única assinatura por anfitrião" do
    subscription = create(:subscription)
    duplicate = build(:subscription, host: subscription.host)
    expect(duplicate).not_to be_valid
  end

  describe "#trial_days_left" do
    it "conta os dias restantes, sem ficar negativo" do
      subscription = create(:subscription, trial_ends_at: 3.days.from_now)
      expect(subscription.trial_days_left).to eq(3)

      expired = create(:subscription, trial_ends_at: 2.days.ago)
      expect(expired.trial_days_left).to eq(0)
    end
  end
end
```

Criar `spec/requests/registrations_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe "Cadastro do anfitrião", type: :request do
  before { create(:plan, slug: "pro", name: "Pro") }

  it "cria conta, inicia trial e loga" do
    expect {
      post registration_path, params: { host: {
        name: "Ana", email_address: "ana@example.com", phone: "11987654321",
        password: "senha-segura-123", password_confirmation: "senha-segura-123"
      } }
    }.to change(Host, :count).by(1).and change(Subscription, :count).by(1)

    host = Host.find_by!(email_address: "ana@example.com")
    expect(host.subscription).to be_trial
    expect(response).to redirect_to(root_path)

    get root_path
    expect(response).to have_http_status(:ok)
  end

  it "reexibe o formulário com erros quando inválido" do
    post registration_path, params: { host: { name: "", email_address: "x", phone: "1",
                                              password: "a", password_confirmation: "b" } }
    expect(response).to have_http_status(:unprocessable_entity)
    expect(Host.count).to eq(0)
  end
end
```

- [ ] **Step 2: Rodar e ver falhar**

Run: `bundle exec rspec spec/models/subscription_spec.rb spec/requests/registrations_spec.rb`
Expected: FAIL ("uninitialized constant Subscription" / rota inexistente)

- [ ] **Step 3: Migration, model, controller, rotas, views**

```bash
bin/rails generate migration CreateSubscriptions
```

```ruby
class CreateSubscriptions < ActiveRecord::Migration[8.1]
  def change
    create_table :subscriptions do |t|
      t.references :host, null: false, foreign_key: true, index: { unique: true }
      t.references :plan, null: false, foreign_key: true
      t.string :status, null: false, default: "trial"
      t.string :billing_cycle
      t.datetime :trial_ends_at

      t.timestamps
    end
  end
end
```

`app/models/subscription.rb`:

```ruby
class Subscription < ApplicationRecord
  STATUSES = %w[trial active past_due canceled].freeze
  CYCLES = %w[monthly quarterly semiannual annual].freeze

  belongs_to :host
  belongs_to :plan

  enum :status, STATUSES.index_by(&:itself), default: "trial"
  enum :billing_cycle, CYCLES.index_by(&:itself)

  validates :host_id, uniqueness: true
  validates :trial_ends_at, presence: true, if: :trial?

  def self.start_trial_for(host)
    create!(
      host: host,
      plan: Plan.find_by!(slug: "pro"),
      status: :trial,
      trial_ends_at: PlatformConfiguration.current.trial_days.days.from_now
    )
  end

  def trial_days_left
    return 0 unless trial? && trial_ends_at
    [ (trial_ends_at.to_date - Date.current).to_i, 0 ].max
  end
end
```

Em `app/models/host.rb`, adicionar após `has_many :sessions`:

```ruby
has_one :subscription, dependent: :destroy
```

Em `app/models/plan.rb`, adicionar no topo do corpo da classe:

```ruby
has_many :subscriptions, dependent: :restrict_with_error
```

`app/controllers/registrations_controller.rb`:

```ruby
class RegistrationsController < ApplicationController
  allow_unauthenticated_access only: %i[new create]

  def new
    @host = Host.new
  end

  def create
    @host = Host.new(host_params)
    if @host.save
      Subscription.start_trial_for(@host)
      start_new_session_for @host
      redirect_to root_path,
                  notice: "Bem-vindo ao Anfitriar! Seu período de teste de #{PlatformConfiguration.current.trial_days} dias começou."
    else
      render :new, status: :unprocessable_entity
    end
  end

  private
    def host_params
      params.expect(host: [ :name, :email_address, :phone, :password, :password_confirmation ])
    end
end
```

Em `config/routes.rb`, adicionar após `resource :session…`:

```ruby
resource :registration, only: %i[new create]
```

`app/views/registrations/new.html.erb`:

```erb
<div class="mx-auto mt-16 max-w-sm">
  <h1 class="mb-2 text-center text-2xl font-bold">Criar conta</h1>
  <p class="mb-6 text-center text-sm text-gray-600">7 dias grátis, sem cartão.</p>
  <%= form_with model: @host, url: registration_path, class: "space-y-4" do |f| %>
    <%= render "shared/form_errors", record: @host %>
    <div>
      <%= f.label :name, class: "block text-sm font-medium" %>
      <%= f.text_field :name, required: true, class: "mt-1 w-full rounded-lg border-gray-300" %>
    </div>
    <div>
      <%= f.label :email_address, class: "block text-sm font-medium" %>
      <%= f.email_field :email_address, required: true, autocomplete: "username",
            class: "mt-1 w-full rounded-lg border-gray-300" %>
    </div>
    <div>
      <%= f.label :phone, class: "block text-sm font-medium" %>
      <%= f.telephone_field :phone, required: true, placeholder: "(11) 98765-4321",
            class: "mt-1 w-full rounded-lg border-gray-300" %>
    </div>
    <div>
      <%= f.label :password, class: "block text-sm font-medium" %>
      <%= f.password_field :password, required: true, autocomplete: "new-password",
            class: "mt-1 w-full rounded-lg border-gray-300" %>
    </div>
    <div>
      <%= f.label :password_confirmation, class: "block text-sm font-medium" %>
      <%= f.password_field :password_confirmation, required: true, autocomplete: "new-password",
            class: "mt-1 w-full rounded-lg border-gray-300" %>
    </div>
    <%= f.submit "Criar conta", class: "w-full rounded-lg bg-gray-900 px-4 py-2 font-medium text-white" %>
  <% end %>
</div>
```

Em `app/views/sessions/new.html.erb`, adicionar antes do fechamento do `div` externo:

```erb
<p class="mt-4 text-center text-sm text-gray-600">
  Ainda não tem conta? <%= link_to "Criar conta", new_registration_path, class: "font-medium underline" %>
</p>
```

Rodar `bin/rails db:migrate`.

- [ ] **Step 4: Rodar e ver passar**

Run: `bundle exec rspec && bin/rubocop`
Expected: PASS, sem ofensas

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "feat: cadastro do anfitrião com trial de 7 dias"
```

---

### Task 5: Recuperação de senha

**Files:**
- Create: `app/controllers/passwords_controller.rb`, `app/mailers/passwords_mailer.rb`
- Create: `app/views/passwords/new.html.erb`, `app/views/passwords/edit.html.erb`, `app/views/passwords_mailer/reset.html.erb`, `app/views/passwords_mailer/reset.text.erb`
- Modify: `config/routes.rb`, `app/mailers/application_mailer.rb`, `app/views/sessions/new.html.erb` (link "Esqueci minha senha")
- Test: `spec/requests/passwords_spec.rb`

**Interfaces:**
- Consumes: `Host` (Task 3) — `has_secure_password` do Rails 8 fornece `password_reset_token` / `Host.find_by_password_reset_token!` (token expira em 15 min).
- Produces: rotas `resources :passwords, param: :token, only: %i[new create edit update]`; `PasswordsMailer.reset(host)`.

- [ ] **Step 1: Escrever specs (falhando)**

Criar `spec/requests/passwords_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe "Recuperação de senha", type: :request do
  let!(:host) { create(:host) }

  it "envia e-mail quando o endereço existe, com resposta idêntica quando não existe" do
    expect {
      post passwords_path, params: { email_address: host.email_address }
    }.to have_enqueued_mail(PasswordsMailer, :reset)
    expect(response).to redirect_to(new_session_path)

    expect {
      post passwords_path, params: { email_address: "nao-existe@example.com" }
    }.not_to have_enqueued_mail
    expect(response).to redirect_to(new_session_path)
  end

  it "redefine a senha com token válido e derruba sessões antigas" do
    sign_in host
    token = host.password_reset_token

    patch password_path(token), params: { host: {
      password: "nova-senha-123", password_confirmation: "nova-senha-123"
    } }

    expect(response).to redirect_to(new_session_path)
    expect(host.reload.authenticate("nova-senha-123")).to be_truthy
    expect(host.sessions.count).to eq(0)
  end

  it "rejeita token inválido" do
    patch password_path("token-invalido"), params: { host: {
      password: "nova-senha-123", password_confirmation: "nova-senha-123"
    } }
    expect(response).to redirect_to(new_password_path)
  end
end
```

- [ ] **Step 2: Rodar e ver falhar**

Run: `bundle exec rspec spec/requests/passwords_spec.rb`
Expected: FAIL (rotas inexistentes)

- [ ] **Step 3: Implementar**

Em `config/routes.rb`, adicionar após `resource :registration…`:

```ruby
resources :passwords, param: :token, only: %i[new create edit update]
```

`app/mailers/application_mailer.rb` (substituir):

```ruby
class ApplicationMailer < ActionMailer::Base
  default from: "Anfitriar <nao-responda@anfitriar.com.br>"
  layout "mailer"
end
```

`app/mailers/passwords_mailer.rb`:

```ruby
class PasswordsMailer < ApplicationMailer
  def reset(host)
    @host = host
    mail subject: "Redefinição de senha — Anfitriar", to: host.email_address
  end
end
```

`app/controllers/passwords_controller.rb`:

```ruby
class PasswordsController < ApplicationController
  allow_unauthenticated_access
  before_action :set_host_by_token, only: %i[edit update]

  def new
  end

  def create
    if host = Host.find_by(email_address: params[:email_address])
      PasswordsMailer.reset(host).deliver_later
    end
    redirect_to new_session_path,
                notice: "Se este e-mail estiver cadastrado, enviaremos instruções para redefinir a senha."
  end

  def edit
  end

  def update
    if @host.update(params.expect(host: [ :password, :password_confirmation ]))
      @host.sessions.destroy_all
      redirect_to new_session_path, notice: "Senha redefinida. Faça login com a nova senha."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private
    def set_host_by_token
      @host = Host.find_by_password_reset_token!(params[:token])
    rescue ActiveSupport::MessageVerifier::InvalidSignature
      redirect_to new_password_path, alert: "O link de redefinição é inválido ou expirou."
    end
end
```

`app/views/passwords/new.html.erb`:

```erb
<div class="mx-auto mt-16 max-w-sm">
  <h1 class="mb-6 text-center text-2xl font-bold">Recuperar senha</h1>
  <%= form_with url: passwords_path, class: "space-y-4" do |f| %>
    <div>
      <%= f.label :email_address, "E-mail", class: "block text-sm font-medium" %>
      <%= f.email_field :email_address, required: true, autofocus: true,
            class: "mt-1 w-full rounded-lg border-gray-300" %>
    </div>
    <%= f.submit "Enviar instruções", class: "w-full rounded-lg bg-gray-900 px-4 py-2 font-medium text-white" %>
  <% end %>
</div>
```

`app/views/passwords/edit.html.erb`:

```erb
<div class="mx-auto mt-16 max-w-sm">
  <h1 class="mb-6 text-center text-2xl font-bold">Nova senha</h1>
  <%= form_with url: password_path(params[:token]), method: :patch, scope: :host, class: "space-y-4" do |f| %>
    <div>
      <%= f.label :password, "Nova senha", class: "block text-sm font-medium" %>
      <%= f.password_field :password, required: true, autocomplete: "new-password",
            class: "mt-1 w-full rounded-lg border-gray-300" %>
    </div>
    <div>
      <%= f.label :password_confirmation, "Confirmar nova senha", class: "block text-sm font-medium" %>
      <%= f.password_field :password_confirmation, required: true, autocomplete: "new-password",
            class: "mt-1 w-full rounded-lg border-gray-300" %>
    </div>
    <%= f.submit "Redefinir senha", class: "w-full rounded-lg bg-gray-900 px-4 py-2 font-medium text-white" %>
  <% end %>
</div>
```

`app/views/passwords_mailer/reset.html.erb`:

```erb
<p>Olá, <%= @host.name %>!</p>
<p>Para redefinir sua senha no Anfitriar, acesse o link abaixo (válido por 15 minutos):</p>
<p><%= link_to "Redefinir senha", edit_password_url(@host.password_reset_token) %></p>
<p>Se você não pediu a redefinição, ignore este e-mail.</p>
```

`app/views/passwords_mailer/reset.text.erb`:

```erb
Olá, <%= @host.name %>!

Para redefinir sua senha no Anfitriar, acesse (válido por 15 minutos):
<%= edit_password_url(@host.password_reset_token) %>

Se você não pediu a redefinição, ignore este e-mail.
```

Em `app/views/sessions/new.html.erb`, adicionar junto ao link de criar conta:

```erb
<p class="mt-2 text-center text-sm text-gray-600">
  <%= link_to "Esqueci minha senha", new_password_path, class: "underline" %>
</p>
```

- [ ] **Step 4: Rodar e ver passar**

Run: `bundle exec rspec && bin/rubocop`
Expected: PASS, sem ofensas

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "feat: recuperação de senha do anfitrião"
```

---

### Task 6: Categorias padrão do sistema com seeds

**Files:**
- Create: `db/migrate/*_create_categories.rb`, `app/models/category.rb`
- Modify: `app/models/host.rb` (associação), `db/seeds.rb`
- Test: `spec/models/category_spec.rb`, `spec/factories/categories.rb`

**Interfaces:**
- Consumes: `Host` (Task 3).
- Produces: `Category` (`name`, `position`, `host_id` NULL = padrão do sistema); `Category.standard` (scope, host_id nulo), `Category.ordered` (position, name), `Category.available_to(host)` → Array ordenado [padrão…, próprias…]; `Category#standard?`; `Host#categories` (próprias); seeds das 11 categorias padrão; factory `:category` (padrão do sistema; trait `:own` com host).

- [ ] **Step 1: Escrever specs (falhando)**

Criar `spec/factories/categories.rb`:

```ruby
FactoryBot.define do
  factory :category do
    sequence(:name) { |n| "Categoria #{n}" }
    sequence(:position)
    host { nil }

    trait :own do
      host
      position { nil }
    end
  end
end
```

Criar `spec/models/category_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe Category do
  it "distingue categorias padrão de próprias" do
    expect(build(:category)).to be_standard
    expect(build(:category, :own)).not_to be_standard
  end

  it "exige nome único dentro do mesmo dono" do
    create(:category, name: "Wi-Fi")
    expect(build(:category, name: "Wi-Fi")).not_to be_valid

    host = create(:host)
    create(:category, :own, host: host, name: "Minha praia")
    expect(build(:category, :own, host: host, name: "Minha praia")).not_to be_valid
  end

  it "permite que uma categoria própria repita o nome de uma padrão" do
    create(:category, name: "Wi-Fi")
    host = create(:host)
    expect(build(:category, :own, host: host, name: "Wi-Fi")).to be_valid
  end

  describe ".available_to" do
    it "lista padrão em ordem de posição e depois as próprias do anfitrião" do
      second = create(:category, name: "B-padrão", position: 2)
      first = create(:category, name: "A-padrão", position: 1)
      host = create(:host)
      own = create(:category, :own, host: host, name: "Minha categoria")
      create(:category, :own, name: "De outro anfitrião")

      expect(described_class.available_to(host)).to eq([ first, second, own ])
    end
  end

  describe "seeds" do
    it "cria as 11 categorias padrão de forma idempotente" do
      2.times { Rails.application.load_seed }
      expect(Category.standard.count).to eq(11)
      expect(Category.standard.ordered.first.name).to eq("Wi-Fi")
      expect(Category.standard.ordered.last.name).to eq("Transporte")
    end
  end
end
```

- [ ] **Step 2: Rodar e ver falhar**

Run: `bundle exec rspec spec/models/category_spec.rb`
Expected: FAIL ("uninitialized constant Category")

- [ ] **Step 3: Migration, model, seeds**

```bash
bin/rails generate migration CreateCategories
```

```ruby
class CreateCategories < ActiveRecord::Migration[8.1]
  def change
    create_table :categories do |t|
      t.string :name, null: false
      t.integer :position
      t.references :host, foreign_key: true

      t.timestamps
    end
  end
end
```

`app/models/category.rb`:

```ruby
class Category < ApplicationRecord
  belongs_to :host, optional: true

  scope :standard, -> { where(host_id: nil) }
  scope :ordered, -> { order(:position, :name) }

  validates :name, presence: true, uniqueness: { scope: :host_id }

  def self.available_to(host)
    standard.ordered + where(host: host).order(:name)
  end

  def standard?
    host_id.nil?
  end
end
```

Em `app/models/host.rb`, adicionar após `has_one :subscription`:

```ruby
has_many :categories, dependent: :destroy
```

Em `db/seeds.rb`, adicionar ao final:

```ruby
# Categorias padrão do sistema (spec §2.3)
[
  "Wi-Fi", "Check-in/Check-out", "Como chegar", "Regras da casa", "Manual da casa",
  "Telefones úteis", "Emergências", "Restaurantes", "Mercados e farmácias",
  "Passeios e atrações", "Transporte"
].each_with_index do |name, index|
  category = Category.standard.find_or_initialize_by(name: name)
  category.update!(position: index + 1)
end
```

Rodar `bin/rails db:migrate`.

- [ ] **Step 4: Rodar e ver passar**

Run: `bundle exec rspec && bin/rubocop`
Expected: PASS, sem ofensas

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "feat: categorias padrão do sistema com seeds"
```

---

### Task 7: CRUD de hospedagens com limite do plano e foto de capa

**Files:**
- Create: `db/migrate/*_create_properties.rb` (+ migração do Active Storage), `app/models/property.rb`, `app/controllers/properties_controller.rb`
- Create: `app/views/properties/index.html.erb`, `app/views/properties/new.html.erb`, `app/views/properties/edit.html.erb`, `app/views/properties/show.html.erb`, `app/views/properties/_form.html.erb`
- Delete: `app/controllers/home_controller.rb`, `app/views/home/index.html.erb`
- Modify: `app/models/host.rb`, `config/routes.rb` (root → properties), `app/views/layouts/_nav.html.erb`
- Test: `spec/models/property_spec.rb`, `spec/requests/properties_spec.rb`, `spec/factories/properties.rb`

**Interfaces:**
- Consumes: `Current.host` (Task 3); `Plan#max_properties`, factory `:plan, :limited` (Task 2); factory `:subscription` (Task 4).
- Produces: `Property` (`belongs_to :host`, `name`, `address`, `has_one_attached :cover_photo`; validação `within_plan_limit` on create); `Host#properties`; rotas `resources :properties` + `root "properties#index"`; factory `:property`. A Task 10 adiciona `guide_entries`/`guide_progress`/`visible_cards` a este model.

- [ ] **Step 1: Instalar Active Storage**

```bash
bin/rails active_storage:install
bin/rails db:migrate
```

- [ ] **Step 2: Escrever specs (falhando)**

Criar `spec/factories/properties.rb`:

```ruby
FactoryBot.define do
  factory :property do
    host
    sequence(:name) { |n| "Apê da Praia #{n}" }
    address { "Rua das Gaivotas, 100 — Florianópolis/SC" }
  end
end
```

Criar `spec/models/property_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe Property do
  it "exige nome e endereço" do
    property = described_class.new(host: create(:host))
    property.valid?
    expect(property.errors[:name]).to be_present
    expect(property.errors[:address]).to be_present
  end

  describe "limite do plano" do
    it "bloqueia criação acima do max_properties do plano" do
      host = create(:host)
      create(:subscription, host: host, plan: create(:plan, :limited))
      create(:property, host: host)

      second = build(:property, host: host)
      expect(second).not_to be_valid
      expect(second.errors[:base].join).to include("limite")
    end

    it "não limita quando o plano é ilimitado" do
      host = create(:host)
      create(:subscription, host: host, plan: create(:plan, max_properties: nil))
      create(:property, host: host)
      expect(build(:property, host: host)).to be_valid
    end

    it "não limita edição de hospedagem existente" do
      host = create(:host)
      property = create(:property, host: host)
      create(:subscription, host: host, plan: create(:plan, :limited))
      property.name = "Novo nome"
      expect(property).to be_valid
    end
  end
end
```

Criar `spec/requests/properties_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe "Hospedagens", type: :request do
  let!(:host) { create(:host) }

  before { sign_in host }

  it "lista apenas as hospedagens do anfitrião logado" do
    mine = create(:property, host: host, name: "Minha Casa")
    create(:property, name: "Casa Alheia")

    get properties_path
    expect(response.body).to include("Minha Casa")
    expect(response.body).not_to include("Casa Alheia")
  end

  it "cria hospedagem para o anfitrião logado" do
    expect {
      post properties_path, params: { property: { name: "Chalé", address: "Serra, 42" } }
    }.to change(host.properties, :count).by(1)
    expect(response).to redirect_to(property_path(host.properties.last))
  end

  it "retorna 404 para hospedagem de outro anfitrião" do
    other = create(:property)
    get property_path(other)
    expect(response).to have_http_status(:not_found)
  end

  it "mostra o erro de limite do plano" do
    host.create_subscription!(plan: create(:plan, :limited), status: "trial", trial_ends_at: 7.days.from_now)
    create(:property, host: host)

    post properties_path, params: { property: { name: "Extra", address: "Rua X" } }
    expect(response).to have_http_status(:unprocessable_entity)
    expect(response.body).to include("limite")
  end

  it "exclui hospedagem" do
    property = create(:property, host: host)
    expect { delete property_path(property) }.to change(host.properties, :count).by(-1)
  end
end
```

- [ ] **Step 3: Rodar e ver falhar**

Run: `bundle exec rspec spec/models/property_spec.rb spec/requests/properties_spec.rb`
Expected: FAIL ("uninitialized constant Property")

- [ ] **Step 4: Migration e model**

```bash
bin/rails generate migration CreateProperties
```

```ruby
class CreateProperties < ActiveRecord::Migration[8.1]
  def change
    create_table :properties do |t|
      t.references :host, null: false, foreign_key: true
      t.string :name, null: false
      t.string :address, null: false

      t.timestamps
    end
  end
end
```

`app/models/property.rb`:

```ruby
class Property < ApplicationRecord
  belongs_to :host
  has_one_attached :cover_photo

  validates :name, :address, presence: true
  validate :within_plan_limit, on: :create

  private
    def within_plan_limit
      return if host.nil?

      limit = host.subscription&.plan&.max_properties
      return if limit.nil?

      if host.properties.count >= limit
        errors.add(:base, "Você atingiu o limite de #{limit} hospedagens do seu plano. Fale com a gente para fazer upgrade.")
      end
    end
end
```

Em `app/models/host.rb`, adicionar após `has_many :categories…`:

```ruby
has_many :properties, dependent: :destroy
```

Rodar `bin/rails db:migrate`.

- [ ] **Step 5: Controller, rotas, views**

`app/controllers/properties_controller.rb`:

```ruby
class PropertiesController < ApplicationController
  before_action :set_property, only: %i[show edit update destroy]

  def index
    @properties = Current.host.properties.order(:name)
  end

  def show
  end

  def new
    @property = Current.host.properties.build
  end

  def create
    @property = Current.host.properties.build(property_params)
    if @property.save
      redirect_to @property, notice: "Hospedagem criada."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @property.update(property_params)
      redirect_to @property, notice: "Hospedagem atualizada."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @property.destroy
    redirect_to properties_path, notice: "Hospedagem excluída."
  end

  private
    def set_property
      @property = Current.host.properties.find(params[:id])
    end

    def property_params
      params.expect(property: [ :name, :address, :cover_photo ])
    end
end
```

Em `config/routes.rb`: trocar `root "home#index"` por `root "properties#index"`, adicionar `resources :properties`, e apagar `app/controllers/home_controller.rb` + `app/views/home/`.

Views (aplicar a skill `impeccable` no refinamento):

`app/views/properties/index.html.erb`:

```erb
<div class="mb-6 flex items-center justify-between">
  <h1 class="text-2xl font-bold">Hospedagens</h1>
  <%= link_to "Nova hospedagem", new_property_path,
        class: "rounded-lg bg-gray-900 px-4 py-2 text-sm font-medium text-white" %>
</div>

<% if @properties.none? %>
  <p class="rounded-lg border border-dashed p-8 text-center text-gray-500">
    Cadastre sua primeira hospedagem para começar a montar o guia do hóspede.
  </p>
<% else %>
  <div class="grid gap-4 sm:grid-cols-2">
    <% @properties.each do |property| %>
      <%= link_to property_path(property), class: "block rounded-lg border bg-white p-4 hover:shadow" do %>
        <% if property.cover_photo.attached? %>
          <%= image_tag property.cover_photo, class: "mb-3 h-32 w-full rounded object-cover" %>
        <% end %>
        <h2 class="font-semibold"><%= property.name %></h2>
        <p class="text-sm text-gray-500"><%= property.address %></p>
      <% end %>
    <% end %>
  </div>
<% end %>
```

`app/views/properties/_form.html.erb`:

```erb
<%= form_with model: property, class: "max-w-lg space-y-4" do |f| %>
  <%= render "shared/form_errors", record: property %>
  <div>
    <%= f.label :name, class: "block text-sm font-medium" %>
    <%= f.text_field :name, required: true, class: "mt-1 w-full rounded-lg border-gray-300" %>
  </div>
  <div>
    <%= f.label :address, class: "block text-sm font-medium" %>
    <%= f.text_field :address, required: true, class: "mt-1 w-full rounded-lg border-gray-300" %>
  </div>
  <div>
    <%= f.label :cover_photo, class: "block text-sm font-medium" %>
    <%= f.file_field :cover_photo, accept: "image/*", class: "mt-1 w-full text-sm" %>
  </div>
  <%= f.submit class: "rounded-lg bg-gray-900 px-4 py-2 font-medium text-white" %>
<% end %>
```

`app/views/properties/new.html.erb`:

```erb
<h1 class="mb-6 text-2xl font-bold">Nova hospedagem</h1>
<%= render "form", property: @property %>
```

`app/views/properties/edit.html.erb`:

```erb
<h1 class="mb-6 text-2xl font-bold">Editar hospedagem</h1>
<%= render "form", property: @property %>
```

`app/views/properties/show.html.erb` (a Task 11 adiciona o bloco do guia; a Task 14, o botão de preview):

```erb
<div class="mb-6 flex items-center justify-between">
  <h1 class="text-2xl font-bold"><%= @property.name %></h1>
  <div class="flex gap-2">
    <%= link_to "Editar", edit_property_path(@property), class: "rounded-lg border px-4 py-2 text-sm" %>
    <%= button_to "Excluir", property_path(@property), method: :delete,
          class: "rounded-lg border border-red-300 px-4 py-2 text-sm text-red-700",
          form: { data: { turbo_confirm: "Excluir esta hospedagem e todo o seu guia?" } } %>
  </div>
</div>
<% if @property.cover_photo.attached? %>
  <%= image_tag @property.cover_photo, class: "mb-4 h-56 w-full rounded-lg object-cover" %>
<% end %>
<p class="text-gray-600"><%= @property.address %></p>
```

Em `app/views/layouts/_nav.html.erb`, adicionar antes do botão de logout:

```erb
<%= link_to t("nav.properties"), properties_path, class: "text-gray-700 hover:text-gray-900" %>
```

- [ ] **Step 6: Rodar e ver passar**

Run: `bundle exec rspec && bin/rubocop`
Expected: PASS (incluindo os specs de autenticação, que continuam válidos com o novo root), sem ofensas

- [ ] **Step 7: Commit**

```bash
git add -A
git commit -m "feat: CRUD de hospedagens com limite do plano e foto de capa"
```

---

### Task 8: CRUD de clientes com CPF criptografado e validado

**Files:**
- Create: `db/migrate/*_create_guests.rb`, `app/models/guest.rb`, `app/validators/cpf_validator.rb`, `app/controllers/guests_controller.rb`
- Create: `app/views/guests/index.html.erb`, `app/views/guests/new.html.erb`, `app/views/guests/edit.html.erb`, `app/views/guests/_form.html.erb`
- Modify: `app/models/host.rb`, `config/routes.rb`, `app/views/layouts/_nav.html.erb`
- Test: `spec/models/guest_spec.rb`, `spec/validators/cpf_validator_spec.rb`, `spec/requests/guests_spec.rb`, `spec/factories/guests.rb`

**Interfaces:**
- Consumes: `Current.host` (Task 3); chaves de AR Encryption (Task 1).
- Produces: `Guest` (`belongs_to :host`; `cpf` criptografado determinístico, `phone` criptografado; `masked_cpf` → `"***.XXX.XXX-**"`; `phone_last_digits(count = 4)` → String — a verificação do hóspede no Subprojeto 3 usará este método); `CpfValidator` (`ActiveModel::EachValidator`; `CpfValidator.valid?(string)`, `CpfValidator.generate(seed)` → CPF válido de 11 dígitos para factories); `Host#guests`; rotas `resources :guests, except: %i[show]`; factory `:guest`.

- [ ] **Step 1: Escrever specs (falhando)**

Criar `spec/validators/cpf_validator_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe CpfValidator do
  describe ".valid?" do
    it "aceita CPF válido" do
      expect(described_class.valid?("39053344705")).to be true
      expect(described_class.valid?("390.533.447-05")).to be true
    end

    it "rejeita dígitos verificadores errados" do
      expect(described_class.valid?("39053344706")).to be false
    end

    it "rejeita sequências repetidas e tamanhos errados" do
      expect(described_class.valid?("11111111111")).to be false
      expect(described_class.valid?("123")).to be false
      expect(described_class.valid?("")).to be false
    end
  end

  describe ".generate" do
    it "gera CPFs válidos e distintos" do
      first = described_class.generate(1)
      second = described_class.generate(2)
      expect(described_class.valid?(first)).to be true
      expect(described_class.valid?(second)).to be true
      expect(first).not_to eq(second)
    end
  end
end
```

Criar `spec/factories/guests.rb`:

```ruby
FactoryBot.define do
  factory :guest do
    host
    name { "Carlos Hóspede" }
    sequence(:cpf) { |n| CpfValidator.generate(n) }
    phone { "11912345678" }
  end
end
```

Criar `spec/models/guest_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe Guest do
  it "normaliza CPF e telefone para dígitos" do
    guest = create(:guest, cpf: "390.533.447-05", phone: "(11) 91234-5678")
    expect(guest.cpf).to eq("39053344705")
    expect(guest.phone).to eq("11912345678")
  end

  it "rejeita CPF inválido" do
    expect(build(:guest, cpf: "11111111111")).not_to be_valid
  end

  it "exige CPF único por anfitrião, mas permite repetir entre anfitriões" do
    guest = create(:guest, cpf: "39053344705")
    expect(build(:guest, host: guest.host, cpf: "390.533.447-05")).not_to be_valid
    expect(build(:guest, cpf: "39053344705")).to be_valid
  end

  it "criptografa CPF e telefone no banco" do
    guest = create(:guest, cpf: "39053344705", phone: "11912345678")
    expect(guest.ciphertext_for(:cpf)).not_to include("39053344705")
    expect(guest.ciphertext_for(:phone)).not_to include("11912345678")
  end

  it "mascara o CPF na exibição" do
    guest = create(:guest, cpf: "39053344705")
    expect(guest.masked_cpf).to eq("***.533.447-**")
  end

  it "expõe os últimos dígitos do telefone" do
    guest = create(:guest, phone: "11912345678")
    expect(guest.phone_last_digits).to eq("5678")
  end

  it "aceita e-mail em branco, rejeita e-mail malformado" do
    expect(build(:guest, email: "")).to be_valid
    expect(build(:guest, email: "invalido")).not_to be_valid
  end
end
```

Criar `spec/requests/guests_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe "Clientes", type: :request do
  let!(:host) { create(:host) }

  before { sign_in host }

  it "lista apenas clientes do anfitrião, com CPF mascarado" do
    create(:guest, host: host, name: "Meu Cliente", cpf: "39053344705")
    create(:guest, name: "Cliente Alheio")

    get guests_path
    expect(response.body).to include("Meu Cliente")
    expect(response.body).to include("***.533.447-**")
    expect(response.body).not_to include("39053344705")
    expect(response.body).not_to include("Cliente Alheio")
  end

  it "cria cliente" do
    expect {
      post guests_path, params: { guest: { name: "Novo", cpf: "390.533.447-05", phone: "11912345678", email: "" } }
    }.to change(host.guests, :count).by(1)
  end

  it "retorna 404 ao editar cliente de outro anfitrião" do
    other = create(:guest)
    get edit_guest_path(other)
    expect(response).to have_http_status(:not_found)
  end

  it "exclui cliente definitivamente" do
    guest = create(:guest, host: host)
    expect { delete guest_path(guest) }.to change(Guest, :count).by(-1)
  end
end
```

- [ ] **Step 2: Rodar e ver falhar**

Run: `bundle exec rspec spec/validators spec/models/guest_spec.rb spec/requests/guests_spec.rb`
Expected: FAIL ("uninitialized constant CpfValidator" / "Guest")

- [ ] **Step 3: Validator, migration, model**

Criar `app/validators/cpf_validator.rb`:

```ruby
class CpfValidator < ActiveModel::EachValidator
  def validate_each(record, attribute, value)
    return if value.blank?
    record.errors.add(attribute, :invalid) unless self.class.valid?(value)
  end

  def self.valid?(value)
    digits = value.to_s.gsub(/\D/, "")
    return false unless digits.length == 11
    return false if digits.chars.uniq.one?

    [ 9, 10 ].all? { |length| digits[length].to_i == check_digit(digits[0, length]) }
  end

  def self.check_digit(partial)
    weights = (2..partial.length + 1).to_a.reverse
    sum = partial.chars.each_with_index.sum { |digit, index| digit.to_i * weights[index] }
    remainder = sum % 11
    remainder < 2 ? 0 : 11 - remainder
  end

  def self.generate(seed)
    base = format("%09d", seed % 999_999_999)
    base = "123456789" if base.chars.uniq.one?
    first = check_digit(base)
    second = check_digit("#{base}#{first}")
    "#{base}#{first}#{second}"
  end
end
```

```bash
bin/rails generate migration CreateGuests
```

```ruby
class CreateGuests < ActiveRecord::Migration[8.1]
  def change
    create_table :guests do |t|
      t.references :host, null: false, foreign_key: true
      t.string :name, null: false
      t.string :cpf, null: false
      t.string :phone, null: false
      t.string :email

      t.timestamps
    end

    add_index :guests, [ :host_id, :cpf ], unique: true
  end
end
```

`app/models/guest.rb`:

```ruby
class Guest < ApplicationRecord
  belongs_to :host

  encrypts :cpf, deterministic: true
  encrypts :phone

  normalizes :cpf, with: ->(c) { c.gsub(/\D/, "") }
  normalizes :phone, with: ->(p) { p.gsub(/\D/, "") }
  normalizes :email, with: ->(e) { e.strip.downcase.presence }

  validates :name, presence: true
  validates :cpf, presence: true, cpf: true, uniqueness: { scope: :host_id }
  validates :phone, presence: true,
            format: { with: /\A\d{10,11}\z/, message: "deve ter DDD + número (10 ou 11 dígitos)" }
  validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }, allow_nil: true

  def masked_cpf
    "***.#{cpf[3..5]}.#{cpf[6..8]}-**"
  end

  def phone_last_digits(count = 4)
    phone.last(count)
  end
end
```

Em `app/models/host.rb`, adicionar após `has_many :properties…`:

```ruby
has_many :guests, dependent: :destroy
```

Rodar `bin/rails db:migrate`.

- [ ] **Step 4: Controller, rotas, views**

`app/controllers/guests_controller.rb`:

```ruby
class GuestsController < ApplicationController
  before_action :set_guest, only: %i[edit update destroy]

  def index
    @guests = Current.host.guests.order(:name)
  end

  def new
    @guest = Current.host.guests.build
  end

  def create
    @guest = Current.host.guests.build(guest_params)
    if @guest.save
      redirect_to guests_path, notice: "Cliente cadastrado."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @guest.update(guest_params)
      redirect_to guests_path, notice: "Cliente atualizado."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @guest.destroy
    redirect_to guests_path, notice: "Cliente excluído. Os dados dele foram removidos."
  end

  private
    def set_guest
      @guest = Current.host.guests.find(params[:id])
    end

    def guest_params
      params.expect(guest: [ :name, :cpf, :phone, :email ])
    end
end
```

Em `config/routes.rb`, adicionar `resources :guests, except: %i[show]`.

`app/views/guests/index.html.erb`:

```erb
<div class="mb-6 flex items-center justify-between">
  <h1 class="text-2xl font-bold">Clientes</h1>
  <%= link_to "Novo cliente", new_guest_path,
        class: "rounded-lg bg-gray-900 px-4 py-2 text-sm font-medium text-white" %>
</div>

<% if @guests.none? %>
  <p class="rounded-lg border border-dashed p-8 text-center text-gray-500">
    Cadastre um cliente para poder criar reservas e liberar o guia.
  </p>
<% else %>
  <div class="overflow-x-auto rounded-lg border bg-white">
    <table class="w-full text-sm">
      <thead class="bg-gray-50 text-left">
        <tr>
          <th class="px-4 py-2">Nome</th>
          <th class="px-4 py-2">CPF</th>
          <th class="px-4 py-2">Telefone</th>
          <th class="px-4 py-2"></th>
        </tr>
      </thead>
      <tbody>
        <% @guests.each do |guest| %>
          <tr class="border-t">
            <td class="px-4 py-2"><%= guest.name %></td>
            <td class="px-4 py-2 tabular-nums"><%= guest.masked_cpf %></td>
            <td class="px-4 py-2 tabular-nums"><%= guest.phone %></td>
            <td class="px-4 py-2 text-right">
              <%= link_to "Editar", edit_guest_path(guest), class: "underline" %>
              <%= button_to "Excluir", guest_path(guest), method: :delete, class: "ml-2 text-red-700 underline",
                    form: { class: "inline", data: { turbo_confirm: "Excluir este cliente e seus dados?" } } %>
            </td>
          </tr>
        <% end %>
      </tbody>
    </table>
  </div>
<% end %>
```

`app/views/guests/_form.html.erb`:

```erb
<%= form_with model: guest, class: "max-w-lg space-y-4" do |f| %>
  <%= render "shared/form_errors", record: guest %>
  <div>
    <%= f.label :name, class: "block text-sm font-medium" %>
    <%= f.text_field :name, required: true, class: "mt-1 w-full rounded-lg border-gray-300" %>
  </div>
  <div>
    <%= f.label :cpf, class: "block text-sm font-medium" %>
    <%= f.text_field :cpf, required: true, placeholder: "000.000.000-00",
          class: "mt-1 w-full rounded-lg border-gray-300" %>
  </div>
  <div>
    <%= f.label :phone, class: "block text-sm font-medium" %>
    <%= f.telephone_field :phone, required: true, placeholder: "(11) 91234-5678",
          class: "mt-1 w-full rounded-lg border-gray-300" %>
    <p class="mt-1 text-xs text-gray-500">O hóspede confirmará o acesso ao guia com o CPF e os 4 últimos dígitos deste telefone.</p>
  </div>
  <div>
    <%= f.label :email, "E-mail (opcional)", class: "block text-sm font-medium" %>
    <%= f.email_field :email, class: "mt-1 w-full rounded-lg border-gray-300" %>
  </div>
  <%= f.submit class: "rounded-lg bg-gray-900 px-4 py-2 font-medium text-white" %>
<% end %>
```

`app/views/guests/new.html.erb`:

```erb
<h1 class="mb-6 text-2xl font-bold">Novo cliente</h1>
<%= render "form", guest: @guest %>
```

`app/views/guests/edit.html.erb`:

```erb
<h1 class="mb-6 text-2xl font-bold">Editar cliente</h1>
<%= render "form", guest: @guest %>
```

Em `app/views/layouts/_nav.html.erb`, adicionar após o link de hospedagens:

```erb
<%= link_to t("nav.guests"), guests_path, class: "text-gray-700 hover:text-gray-900" %>
```

- [ ] **Step 5: Rodar e ver passar**

Run: `bundle exec rspec && bin/rubocop`
Expected: PASS, sem ofensas

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "feat: CRUD de clientes com CPF criptografado e validado"
```

---

### Task 9: CRUD de categorias próprias do anfitrião

**Files:**
- Create: `app/controllers/categories_controller.rb`, `app/views/categories/index.html.erb`, `app/views/categories/new.html.erb`, `app/views/categories/edit.html.erb`, `app/views/categories/_form.html.erb`
- Modify: `config/routes.rb`, `app/views/layouts/_nav.html.erb`
- Test: `spec/requests/categories_spec.rb`

**Interfaces:**
- Consumes: `Category` (Task 6), `Current.host` (Task 3).
- Produces: rotas `resources :categories, except: %i[show]`; tela que lista padrão (somente leitura) e próprias (com ações). O escopo `Current.host.categories` garante 404 para categorias padrão ou de terceiros.

- [ ] **Step 1: Escrever specs (falhando)**

Criar `spec/requests/categories_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe "Categorias", type: :request do
  let!(:host) { create(:host) }

  before { sign_in host }

  it "lista categorias padrão como referência e as próprias com ações" do
    create(:category, name: "Wi-Fi", position: 1)
    create(:category, :own, host: host, name: "Minha adega")

    get categories_path
    expect(response.body).to include("Wi-Fi")
    expect(response.body).to include("Minha adega")
  end

  it "cria categoria própria" do
    expect {
      post categories_path, params: { category: { name: "Passeios de barco" } }
    }.to change(host.categories, :count).by(1)
  end

  it "não permite editar nem excluir categoria padrão (404)" do
    standard = create(:category, name: "Wi-Fi", position: 1)

    get edit_category_path(standard)
    expect(response).to have_http_status(:not_found)

    delete category_path(standard)
    expect(response).to have_http_status(:not_found)
    expect(Category.exists?(standard.id)).to be true
  end

  it "não permite mexer em categoria própria de outro anfitrião (404)" do
    other = create(:category, :own)
    delete category_path(other)
    expect(response).to have_http_status(:not_found)
  end

  it "exclui categoria própria" do
    category = create(:category, :own, host: host)
    expect { delete category_path(category) }.to change(host.categories, :count).by(-1)
  end
end
```

- [ ] **Step 2: Rodar e ver falhar**

Run: `bundle exec rspec spec/requests/categories_spec.rb`
Expected: FAIL (rotas inexistentes)

- [ ] **Step 3: Controller, rotas, views**

`app/controllers/categories_controller.rb`:

```ruby
class CategoriesController < ApplicationController
  before_action :set_category, only: %i[edit update destroy]

  def index
    @standard_categories = Category.standard.ordered
    @own_categories = Current.host.categories.order(:name)
  end

  def new
    @category = Current.host.categories.build
  end

  def create
    @category = Current.host.categories.build(category_params)
    if @category.save
      redirect_to categories_path, notice: "Categoria criada."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @category.update(category_params)
      redirect_to categories_path, notice: "Categoria atualizada."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @category.destroy
    redirect_to categories_path, notice: "Categoria excluída."
  end

  private
    def set_category
      @category = Current.host.categories.find(params[:id])
    end

    def category_params
      params.expect(category: [ :name ])
    end
end
```

Em `config/routes.rb`, adicionar `resources :categories, except: %i[show]`.

`app/views/categories/index.html.erb`:

```erb
<div class="mb-6 flex items-center justify-between">
  <h1 class="text-2xl font-bold">Categorias</h1>
  <%= link_to "Nova categoria", new_category_path,
        class: "rounded-lg bg-gray-900 px-4 py-2 text-sm font-medium text-white" %>
</div>

<h2 class="mb-2 text-sm font-semibold uppercase text-gray-500">Padrão do sistema</h2>
<p class="mb-3 text-sm text-gray-500">Estas categorias existem em todas as contas. Você preenche a descrição de cada uma dentro de cada hospedagem — e pode ocultá-las por hospedagem, mas não excluí-las.</p>
<ul class="mb-8 grid gap-2 sm:grid-cols-2">
  <% @standard_categories.each do |category| %>
    <li class="rounded-lg border bg-white px-4 py-2 text-sm"><%= category.name %></li>
  <% end %>
</ul>

<h2 class="mb-2 text-sm font-semibold uppercase text-gray-500">Minhas categorias</h2>
<% if @own_categories.none? %>
  <p class="rounded-lg border border-dashed p-6 text-center text-sm text-gray-500">
    Crie categorias próprias para assuntos que só existem nas suas hospedagens.
  </p>
<% else %>
  <ul class="grid gap-2 sm:grid-cols-2">
    <% @own_categories.each do |category| %>
      <li class="flex items-center justify-between rounded-lg border bg-white px-4 py-2 text-sm">
        <%= category.name %>
        <span>
          <%= link_to "Editar", edit_category_path(category), class: "underline" %>
          <%= button_to "Excluir", category_path(category), method: :delete, class: "ml-2 text-red-700 underline",
                form: { class: "inline", data: { turbo_confirm: "Excluir esta categoria remove os cards dela em todas as hospedagens. Confirmar?" } } %>
        </span>
      </li>
    <% end %>
  </ul>
<% end %>
```

`app/views/categories/_form.html.erb`:

```erb
<%= form_with model: category, class: "max-w-lg space-y-4" do |f| %>
  <%= render "shared/form_errors", record: category %>
  <div>
    <%= f.label :name, class: "block text-sm font-medium" %>
    <%= f.text_field :name, required: true, class: "mt-1 w-full rounded-lg border-gray-300" %>
  </div>
  <%= f.submit class: "rounded-lg bg-gray-900 px-4 py-2 font-medium text-white" %>
<% end %>
```

`app/views/categories/new.html.erb`:

```erb
<h1 class="mb-6 text-2xl font-bold">Nova categoria</h1>
<%= render "form", category: @category %>
```

`app/views/categories/edit.html.erb`:

```erb
<h1 class="mb-6 text-2xl font-bold">Editar categoria</h1>
<%= render "form", category: @category %>
```

Em `app/views/layouts/_nav.html.erb`, adicionar após o link de clientes:

```erb
<%= link_to t("nav.categories"), categories_path, class: "text-gray-700 hover:text-gray-900" %>
```

- [ ] **Step 4: Rodar e ver passar**

Run: `bundle exec rspec && bin/rubocop`
Expected: PASS, sem ofensas

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "feat: CRUD de categorias próprias do anfitrião"
```

---

### Task 10: Cards do guia (Action Text) com progresso de preenchimento

**Files:**
- Create: `db/migrate/*_create_cards.rb` (+ migração do Action Text), `app/models/card.rb`
- Modify: `Gemfile`/`config/importmap.rb`/layout (via `action_text:install`), `app/models/property.rb`, `app/models/category.rb`
- Test: `spec/models/card_spec.rb`, `spec/models/property_guide_spec.rb`, `spec/factories/cards.rb`

**Interfaces:**
- Consumes: `Property` (Task 7), `Category.available_to` (Task 6).
- Produces: `Card` (`belongs_to :property/:category`, `has_rich_text :description`, `hidden` boolean, `position` int, único por property+category; `Card#filled?`; `Card.upsert_for(property, category, attributes)` → Card; scope `Card.by_position`); `Property#guide_entries` → Array de pares `[category, card_ou_nil]`; `Property#guide_progress` → `{ filled: Integer, total: Integer }`; `Property#visible_cards` → Array de cards preenchidos e não ocultos, em ordem; `Category#cards` (`dependent: :destroy` — excluir categoria própria remove os cards, spec §4).

- [ ] **Step 1: Instalar Action Text**

```bash
bin/rails action_text:install
bin/rails db:migrate
```

Conferir o que o instalador alterou (importmap pins de `trix` e `@rails/actiontext`, stylesheet). Se ele criar `app/assets/stylesheets/actiontext.css` sem referenciá-lo, adicionar no `<head>` do layout, junto aos outros stylesheets:

```erb
<%= stylesheet_link_tag "actiontext", "data-turbo-track": "reload" %>
```

- [ ] **Step 2: Escrever specs (falhando)**

Criar `spec/factories/cards.rb`:

```ruby
FactoryBot.define do
  factory :card do
    property
    category
    description { "<p>Conteúdo do card</p>" }
    hidden { false }
  end
end
```

Criar `spec/models/card_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe Card do
  it "é único por hospedagem + categoria" do
    card = create(:card)
    duplicate = build(:card, property: card.property, category: card.category)
    expect(duplicate).not_to be_valid
  end

  describe "#filled?" do
    it "é verdadeiro só com descrição presente" do
      expect(build(:card, description: "<p>Wi-Fi: casa123</p>")).to be_filled
      expect(build(:card, description: nil)).not_to be_filled
    end
  end

  describe ".upsert_for" do
    it "cria o card na primeira escrita e atualiza depois, sem duplicar" do
      property = create(:property)
      category = create(:category, position: 1)

      expect {
        described_class.upsert_for(property, category, description: "<p>v1</p>")
      }.to change(described_class, :count).by(1)

      expect {
        described_class.upsert_for(property, category, description: "<p>v2</p>")
      }.not_to change(described_class, :count)

      expect(property.cards.sole.description.to_plain_text).to eq("v2")
    end

    it "atualiza só o que foi passado, preservando o resto" do
      property = create(:property)
      category = create(:category, position: 1)
      described_class.upsert_for(property, category, description: "<p>conteúdo</p>")

      card = described_class.upsert_for(property, category, hidden: true)
      expect(card).to be_hidden
      expect(card.description.to_plain_text).to eq("conteúdo")
    end
  end

  it "morre junto com a categoria própria" do
    host = create(:host)
    category = create(:category, :own, host: host)
    property = create(:property, host: host)
    create(:card, property: property, category: category)

    expect { category.destroy }.to change(described_class, :count).by(-1)
  end
end
```

Criar `spec/models/property_guide_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe Property, "guia" do
  let(:host) { create(:host) }
  let(:property) { create(:property, host: host) }
  let!(:wifi) { create(:category, name: "Wi-Fi", position: 1) }
  let!(:rules) { create(:category, name: "Regras da casa", position: 2) }
  let!(:own) { create(:category, :own, host: host, name: "Minha adega") }

  describe "#guide_entries" do
    it "põe cards existentes em ordem de posição e categorias sem card ao final" do
      rules_card = create(:card, property: property, category: rules, position: 1)

      entries = property.guide_entries
      expect(entries.first).to eq([ rules, rules_card ])
      expect(entries.map(&:first)).to eq([ rules, wifi, own ])
      expect(entries.last(2).map(&:last)).to eq([ nil, nil ])
    end

    it "ignora categorias próprias de outros anfitriões" do
      create(:category, :own, name: "De outro")
      expect(property.guide_entries.map { |category, _| category.name }).not_to include("De outro")
    end
  end

  describe "#guide_progress" do
    it "conta cards preenchidos sobre o total de categorias disponíveis" do
      create(:card, property: property, category: wifi, description: "<p>senha</p>")
      create(:card, property: property, category: rules, description: nil)

      expect(property.guide_progress).to eq(filled: 1, total: 3)
    end
  end

  describe "#visible_cards" do
    it "exclui ocultos e vazios, mantendo a ordem" do
      visible = create(:card, property: property, category: rules, position: 1)
      create(:card, property: property, category: wifi, position: 2, hidden: true)
      create(:card, property: property, category: own, position: 3, description: nil)

      expect(property.visible_cards).to eq([ visible ])
    end
  end
end
```

- [ ] **Step 3: Rodar e ver falhar**

Run: `bundle exec rspec spec/models/card_spec.rb spec/models/property_guide_spec.rb`
Expected: FAIL ("uninitialized constant Card")

- [ ] **Step 4: Migration e models**

```bash
bin/rails generate migration CreateCards
```

```ruby
class CreateCards < ActiveRecord::Migration[8.1]
  def change
    create_table :cards do |t|
      t.references :property, null: false, foreign_key: true
      t.references :category, null: false, foreign_key: true
      t.boolean :hidden, null: false, default: false
      t.integer :position

      t.timestamps
    end

    add_index :cards, [ :property_id, :category_id ], unique: true
  end
end
```

`app/models/card.rb`:

```ruby
class Card < ApplicationRecord
  belongs_to :property
  belongs_to :category

  has_rich_text :description

  validates :category_id, uniqueness: { scope: :property_id }

  scope :by_position, -> { order(position: :asc, id: :asc) }

  def filled?
    description.present?
  end

  def self.upsert_for(property, category, attributes)
    card = property.cards.find_or_initialize_by(category: category)
    card.update(attributes)
    card
  end
end
```

Em `app/models/property.rb`, adicionar após `has_one_attached :cover_photo`:

```ruby
has_many :cards, dependent: :destroy
```

E, antes de `private`:

```ruby
def guide_entries
  existing = cards.by_position.includes(:category, :rich_text_description).to_a
  remaining = Category.available_to(host) - existing.map(&:category)
  existing.map { |card| [ card.category, card ] } + remaining.map { |category| [ category, nil ] }
end

def guide_progress
  categories = Category.available_to(host)
  filled = cards.filter(&:filled?).count { |card| categories.include?(card.category) }
  { filled: filled, total: categories.size }
end

def visible_cards
  cards.by_position.reject(&:hidden?).select(&:filled?)
end
```

Em `app/models/category.rb`, adicionar após `belongs_to :host, optional: true`:

```ruby
has_many :cards, dependent: :destroy
```

Rodar `bin/rails db:migrate`.

- [ ] **Step 5: Rodar e ver passar**

Run: `bundle exec rspec && bin/rubocop`
Expected: PASS, sem ofensas

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "feat: cards do guia (Action Text) com progresso de preenchimento"
```

---

### Task 11: Tela "Montar o guia" com edição, ocultar e reordenar

**Files:**
- Create: `app/controllers/properties/guides_controller.rb`, `app/controllers/properties/guide_cards_controller.rb`, `app/controllers/properties/guide_reorders_controller.rb`
- Create: `app/views/properties/guides/show.html.erb`, `app/javascript/controllers/sortable_controller.js`
- Modify: `config/routes.rb`, `config/importmap.rb` (pin sortablejs), `app/views/properties/show.html.erb` (link + progresso)
- Test: `spec/requests/property_guides_spec.rb`, `spec/system/guide_editing_spec.rb`

**Interfaces:**
- Consumes: `Card.upsert_for`, `Property#guide_entries`, `Property#guide_progress` (Task 10); `Category.available_to` (Task 6).
- Produces: rotas aninhadas em `resources :properties`: `GET properties/:property_id/guide` (`property_guide_path`), `PATCH properties/:property_id/guide/cards/:category_id` (`property_guide_card_path`), `PATCH properties/:property_id/guide/reorder` (`property_guide_reorder_path`, JSON `{ category_ids: [] }`).

- [ ] **Step 1: Pin do SortableJS**

```bash
bin/importmap pin sortablejs
```

(Baixa para `vendor/javascript` — commitar o arquivo baixado.)

- [ ] **Step 2: Escrever specs (falhando)**

Criar `spec/requests/property_guides_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe "Montar o guia", type: :request do
  let!(:host) { create(:host) }
  let!(:property) { create(:property, host: host) }
  let!(:wifi) { create(:category, name: "Wi-Fi", position: 1) }
  let!(:rules) { create(:category, name: "Regras da casa", position: 2) }

  before { sign_in host }

  it "mostra todas as categorias e o progresso" do
    get property_guide_path(property)
    expect(response.body).to include("Wi-Fi")
    expect(response.body).to include("Regras da casa")
    expect(response.body).to include("0 de 2")
  end

  it "salva a descrição de um card (upsert)" do
    patch property_guide_card_path(property, category_id: wifi.id),
          params: { card: { description: "<p>Rede: Casa / Senha: 12345</p>" } }

    expect(response).to redirect_to(property_guide_path(property))
    card = property.cards.sole
    expect(card.category).to eq(wifi)
    expect(card.description.to_plain_text).to include("Casa")
  end

  it "oculta e mostra um card sem apagar a descrição" do
    Card.upsert_for(property, wifi, description: "<p>senha</p>")

    patch property_guide_card_path(property, category_id: wifi.id), params: { card: { hidden: "1" } }
    card = property.cards.sole
    expect(card).to be_hidden
    expect(card.description).to be_present
  end

  it "reordena via lista de category_ids" do
    patch property_guide_reorder_path(property),
          params: { category_ids: [ rules.id.to_s, wifi.id.to_s ] }, as: :json

    expect(response).to have_http_status(:no_content)
    expect(property.guide_entries.map(&:first)).to eq([ rules, wifi ])
  end

  it "rejeita categoria de outro anfitrião no guia (404)" do
    foreign = create(:category, :own)
    patch property_guide_card_path(property, category_id: foreign.id),
          params: { card: { description: "<p>x</p>" } }
    expect(response).to have_http_status(:not_found)
  end

  it "rejeita hospedagem de outro anfitrião (404)" do
    other_property = create(:property)
    get property_guide_path(other_property)
    expect(response).to have_http_status(:not_found)
  end
end
```

Criar `spec/system/guide_editing_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe "Edição do guia", type: :system do
  it "navega da hospedagem para o guia e vê categorias e progresso" do
    host = create(:host, password: "senha-segura-123")
    property = create(:property, host: host, name: "Chalé da Serra")
    create(:category, name: "Wi-Fi", position: 1)
    Card.upsert_for(property, Category.first, description: "<p>Rede: Chalé</p>")

    visit new_session_path
    fill_in "E-mail", with: host.email_address
    fill_in "Senha", with: "senha-segura-123"
    click_button "Entrar"

    click_link "Chalé da Serra"
    click_link "Montar o guia"

    expect(page).to have_content("Wi-Fi")
    expect(page).to have_content("1 de 1")
  end
end
```

- [ ] **Step 3: Rodar e ver falhar**

Run: `bundle exec rspec spec/requests/property_guides_spec.rb spec/system/guide_editing_spec.rb`
Expected: FAIL (rotas inexistentes)

- [ ] **Step 4: Rotas e controllers**

Em `config/routes.rb`, trocar `resources :properties` por:

```ruby
resources :properties do
  scope module: :properties do
    resource :guide, only: :show
    patch "guide/cards/:category_id", to: "guide_cards#update", as: :guide_card
    patch "guide/reorder", to: "guide_reorders#update", as: :guide_reorder
  end
end
```

`app/controllers/properties/guides_controller.rb`:

```ruby
class Properties::GuidesController < ApplicationController
  def show
    @property = Current.host.properties.find(params[:property_id])
    @entries = @property.guide_entries
    @progress = @property.guide_progress
  end
end
```

`app/controllers/properties/guide_cards_controller.rb`:

```ruby
class Properties::GuideCardsController < ApplicationController
  def update
    property = Current.host.properties.find(params[:property_id])
    category = available_category!(property)

    Card.upsert_for(property, category, card_params)
    redirect_to property_guide_path(property), notice: "Guia atualizado."
  end

  private
    def available_category!(property)
      Category.available_to(property.host).find { |category| category.id == params[:category_id].to_i } ||
        raise(ActiveRecord::RecordNotFound)
    end

    def card_params
      params.expect(card: [ :description, :hidden ])
    end
end
```

`app/controllers/properties/guide_reorders_controller.rb`:

```ruby
class Properties::GuideReordersController < ApplicationController
  def update
    property = Current.host.properties.find(params[:property_id])
    available = Category.available_to(property.host).index_by(&:id)

    params.expect(category_ids: []).each_with_index do |category_id, index|
      category = available[category_id.to_i] or next
      Card.upsert_for(property, category, position: index + 1)
    end

    head :no_content
  end
end
```

- [ ] **Step 5: View e Stimulus**

`app/javascript/controllers/sortable_controller.js`:

```javascript
import { Controller } from "@hotwired/stimulus"
import Sortable from "sortablejs"

export default class extends Controller {
  static values = { url: String }

  connect() {
    this.sortable = Sortable.create(this.element, {
      handle: "[data-sortable-handle]",
      animation: 150,
      onEnd: () => this.save()
    })
  }

  disconnect() {
    this.sortable?.destroy()
  }

  async save() {
    const categoryIds = Array.from(this.element.querySelectorAll("[data-category-id]"))
      .map((element) => element.dataset.categoryId)

    await fetch(this.urlValue, {
      method: "PATCH",
      headers: {
        "Content-Type": "application/json",
        "X-CSRF-Token": document.querySelector("meta[name='csrf-token']").content
      },
      body: JSON.stringify({ category_ids: categoryIds })
    })
  }
}
```

`app/views/properties/guides/show.html.erb`:

```erb
<div class="mb-2 flex items-center justify-between">
  <h1 class="text-2xl font-bold">Montar o guia — <%= @property.name %></h1>
  <%= link_to "Voltar", property_path(@property), class: "text-sm underline" %>
</div>
<p class="mb-6 text-sm text-gray-600">
  <span class="font-semibold"><%= @progress[:filled] %> de <%= @progress[:total] %></span> categorias preenchidas.
  Categorias sem descrição ou ocultas não aparecem para o hóspede. Arraste pelo símbolo ⠿ para reordenar.
</p>

<div class="space-y-4" data-controller="sortable" data-sortable-url-value="<%= property_guide_reorder_path(@property) %>">
  <% @entries.each do |category, card| %>
    <div class="rounded-lg border bg-white p-4 <%= "opacity-60" if card&.hidden? %>" data-category-id="<%= category.id %>">
      <div class="mb-2 flex items-center justify-between">
        <div class="flex items-center gap-2">
          <span data-sortable-handle class="cursor-grab select-none text-gray-400">⠿</span>
          <h2 class="font-semibold"><%= category.name %></h2>
          <% unless category.standard? %>
            <span class="rounded bg-gray-100 px-2 py-0.5 text-xs text-gray-600">minha categoria</span>
          <% end %>
          <% if card&.hidden? %>
            <span class="rounded bg-yellow-100 px-2 py-0.5 text-xs text-yellow-800">oculta neste guia</span>
          <% end %>
        </div>
        <%= form_with url: property_guide_card_path(@property, category_id: category.id), method: :patch, scope: :card do |f| %>
          <%= f.hidden_field :hidden, value: card&.hidden? ? "0" : "1" %>
          <%= f.submit card&.hidden? ? "Mostrar" : "Ocultar", class: "text-sm underline" %>
        <% end %>
      </div>
      <%= form_with url: property_guide_card_path(@property, category_id: category.id), method: :patch, scope: :card do |f| %>
        <%= f.rich_text_area :description, value: card&.description %>
        <%= f.submit "Salvar", class: "mt-2 rounded-lg bg-gray-900 px-4 py-1.5 text-sm font-medium text-white" %>
      <% end %>
    </div>
  <% end %>
</div>
```

Em `app/views/properties/show.html.erb`, adicionar ao final:

```erb
<% progress = @property.guide_progress %>
<div class="mt-6 rounded-lg border bg-white p-4">
  <div class="flex items-center justify-between">
    <div>
      <h2 class="font-semibold">Guia do hóspede</h2>
      <p class="text-sm text-gray-600"><%= progress[:filled] %> de <%= progress[:total] %> categorias preenchidas</p>
    </div>
    <%= link_to "Montar o guia", property_guide_path(@property),
          class: "rounded-lg bg-gray-900 px-4 py-2 text-sm font-medium text-white" %>
  </div>
</div>
```

- [ ] **Step 6: Rodar e ver passar**

Run: `bundle exec rspec && bin/rubocop`
Expected: PASS, sem ofensas

- [ ] **Step 7: Commit**

```bash
git add -A
git commit -m "feat: tela montar o guia com edição, ocultar e reordenar"
```

---

### Task 12: Reservas — modelo com link de acesso, janela e revogação

**Files:**
- Create: `db/migrate/*_create_bookings.rb`, `app/models/booking.rb`
- Modify: `app/models/host.rb`, `app/models/property.rb`, `app/models/guest.rb` (associações)
- Test: `spec/models/booking_spec.rb`, `spec/factories/bookings.rb`

**Interfaces:**
- Consumes: `Property`, `Guest` (Tasks 7–8); `PlatformConfiguration.current.booking_access_margin_days` (Task 2).
- Produces: `Booking` (`belongs_to :property/:guest`, `check_in`/`check_out` date, `has_secure_token :access_token`, `revoked_at`); `#accessible_until` → Date (check_out + margem); `#link_active?`; `#revoked?`; `#revoke!`; `#reissue!` (novo token + revogação limpa); validações (datas presentes, check_out > check_in, guest do mesmo host); scopes `within_window`, `finished`, `recent_first`; `Host#bookings` (through properties); factory `:booking` (guest do mesmo host da property).

- [ ] **Step 1: Escrever specs (falhando)**

Criar `spec/factories/bookings.rb`:

```ruby
FactoryBot.define do
  factory :booking do
    property
    guest { association :guest, host: property.host }
    check_in { Date.current }
    check_out { Date.current + 3 }
  end
end
```

Criar `spec/models/booking_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe Booking do
  it "gera token de acesso na criação" do
    booking = create(:booking)
    expect(booking.access_token).to be_present
    expect(booking.access_token.length).to be >= 24
  end

  it "exige check-out depois do check-in" do
    booking = build(:booking, check_in: Date.current, check_out: Date.current)
    expect(booking).not_to be_valid
    expect(booking.errors[:check_out]).to be_present
  end

  it "rejeita cliente de outro anfitrião" do
    booking = build(:booking, guest: create(:guest))
    expect(booking).not_to be_valid
    expect(booking.errors[:guest]).to be_present
  end

  describe "janela de acesso (margem padrão: 2 dias)" do
    it "calcula accessible_until e link_active?" do
      booking = create(:booking, check_in: Date.current - 5, check_out: Date.current - 1)
      expect(booking.accessible_until).to eq(Date.current + 1)
      expect(booking).to be_link_active

      expired = create(:booking, check_in: Date.current - 10, check_out: Date.current - 3)
      expect(expired).not_to be_link_active
    end
  end

  describe "revogação" do
    it "revoke! desativa o link" do
      booking = create(:booking)
      booking.revoke!
      expect(booking).to be_revoked
      expect(booking).not_to be_link_active
    end

    it "reissue! troca o token e reativa" do
      booking = create(:booking)
      booking.revoke!
      old_token = booking.access_token

      booking.reissue!
      expect(booking.access_token).not_to eq(old_token)
      expect(booking).to be_link_active
    end
  end

  describe "scopes" do
    it "separa reservas na janela das encerradas" do
      current = create(:booking, check_in: Date.current - 3, check_out: Date.current - 1)
      finished = create(:booking, check_in: Date.current - 10, check_out: Date.current - 5)

      expect(described_class.within_window).to include(current)
      expect(described_class.within_window).not_to include(finished)
      expect(described_class.finished).to include(finished)
      expect(described_class.finished).not_to include(current)
    end
  end
end
```

- [ ] **Step 2: Rodar e ver falhar**

Run: `bundle exec rspec spec/models/booking_spec.rb`
Expected: FAIL ("uninitialized constant Booking")

- [ ] **Step 3: Migration e model**

```bash
bin/rails generate migration CreateBookings
```

```ruby
class CreateBookings < ActiveRecord::Migration[8.1]
  def change
    create_table :bookings do |t|
      t.references :property, null: false, foreign_key: true
      t.references :guest, null: false, foreign_key: true
      t.date :check_in, null: false
      t.date :check_out, null: false
      t.string :access_token, null: false, index: { unique: true }
      t.datetime :revoked_at

      t.timestamps
    end
  end
end
```

`app/models/booking.rb`:

```ruby
class Booking < ApplicationRecord
  belongs_to :property
  belongs_to :guest

  has_secure_token :access_token

  scope :within_window, -> {
    where(check_out: (Date.current - PlatformConfiguration.current.booking_access_margin_days)..)
  }
  scope :finished, -> {
    where(check_out: ...(Date.current - PlatformConfiguration.current.booking_access_margin_days))
  }
  scope :recent_first, -> { order(check_in: :desc) }

  validates :check_in, :check_out, presence: true
  validate :check_out_after_check_in
  validate :guest_belongs_to_property_host

  def accessible_until
    check_out + PlatformConfiguration.current.booking_access_margin_days
  end

  def revoked?
    revoked_at.present?
  end

  def link_active?
    !revoked? && Date.current <= accessible_until
  end

  def revoke!
    update!(revoked_at: Time.current)
  end

  def reissue!
    regenerate_access_token
    update!(revoked_at: nil)
  end

  private
    def check_out_after_check_in
      return if check_in.blank? || check_out.blank?
      errors.add(:check_out, "deve ser depois do check-in") if check_out <= check_in
    end

    def guest_belongs_to_property_host
      return if guest.nil? || property.nil?
      errors.add(:guest, "não pertence à sua conta") if guest.host_id != property.host_id
    end
end
```

Associações: em `app/models/host.rb`, após `has_many :guests…`:

```ruby
has_many :bookings, through: :properties
```

Em `app/models/property.rb`, após `has_many :cards…`:

```ruby
has_many :bookings, dependent: :destroy
```

Em `app/models/guest.rb`, após `belongs_to :host`:

```ruby
has_many :bookings, dependent: :destroy
```

Rodar `bin/rails db:migrate`.

- [ ] **Step 4: Rodar e ver passar**

Run: `bundle exec rspec && bin/rubocop`
Expected: PASS, sem ofensas

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "feat: reservas com link de acesso, janela e revogação (modelo)"
```

---

### Task 13: Reservas — telas com link, copiar, WhatsApp e regenerar (+ rota pública placeholder)

**Files:**
- Create: `app/controllers/bookings_controller.rb`, `app/controllers/public_guides_controller.rb`, `app/helpers/bookings_helper.rb`
- Create: `app/views/bookings/index.html.erb`, `app/views/bookings/new.html.erb`, `app/views/bookings/show.html.erb`, `app/views/bookings/_form.html.erb`, `app/views/bookings/_list.html.erb`, `app/views/public_guides/show.html.erb`
- Create: `app/javascript/controllers/clipboard_controller.js`
- Modify: `config/routes.rb`, `app/views/layouts/_nav.html.erb`
- Test: `spec/requests/bookings_spec.rb`, `spec/requests/public_guides_spec.rb`, `spec/system/booking_creation_spec.rb`

**Interfaces:**
- Consumes: `Booking` completo (Task 12); `Guest#phone`, `masked_cpf` (Task 8).
- Produces: rotas `resources :bookings, only: %i[index new create show]` + `patch :revoke/:reissue` member; rota pública `get "g/:token" => "public_guides#show", as: :public_guide` (página neutra "em construção", mesma resposta para qualquer token — o guia real é o Subprojeto 3); helpers `guide_link_for(booking)` → URL pública e `whatsapp_share_url(booking)` → `https://wa.me/55<phone>?text=<mensagem com o link>`.

- [ ] **Step 1: Escrever specs (falhando)**

Criar `spec/requests/bookings_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe "Reservas", type: :request do
  let!(:host) { create(:host) }
  let!(:property) { create(:property, host: host) }
  let!(:guest) { create(:guest, host: host) }

  before { sign_in host }

  it "cria reserva e mostra o link de acesso" do
    expect {
      post bookings_path, params: { booking: {
        property_id: property.id, guest_id: guest.id,
        check_in: Date.current, check_out: Date.current + 3
      } }
    }.to change(Booking, :count).by(1)

    booking = Booking.last
    follow_redirect!
    expect(response.body).to include(booking.access_token)
    expect(response.body).to include("wa.me/55#{guest.phone}")
  end

  it "rejeita hospedagem ou cliente de outro anfitrião (404)" do
    foreign_property = create(:property)
    post bookings_path, params: { booking: {
      property_id: foreign_property.id, guest_id: guest.id,
      check_in: Date.current, check_out: Date.current + 2
    } }
    expect(response).to have_http_status(:not_found)
  end

  it "separa reservas ativas de encerradas no índice" do
    create(:booking, property: property, guest: guest,
           check_in: Date.current, check_out: Date.current + 2)
    create(:booking, property: property, guest: guest,
           check_in: Date.current - 10, check_out: Date.current - 5)

    get bookings_path
    expect(response.body).to include("Ativas e futuras")
    expect(response.body).to include("Encerradas")
  end

  it "revoga e regenera o link" do
    booking = create(:booking, property: property, guest: guest)
    original_token = booking.access_token

    patch revoke_booking_path(booking)
    expect(booking.reload).to be_revoked

    patch reissue_booking_path(booking)
    booking.reload
    expect(booking).not_to be_revoked
    expect(booking.access_token).not_to eq(original_token)
  end

  it "não permite revogar reserva de outro anfitrião (404)" do
    other = create(:booking)
    patch revoke_booking_path(other)
    expect(response).to have_http_status(:not_found)
  end
end
```

Criar `spec/requests/public_guides_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe "Rota pública do guia (placeholder)", type: :request do
  it "responde igual para qualquer token, sem exigir login e sem vazar dados" do
    booking = create(:booking)

    get public_guide_path(token: booking.access_token)
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("em preparação")
    expect(response.body).not_to include(booking.guest.name)
    expect(response.body).not_to include(booking.property.name)

    get public_guide_path(token: "token-que-nao-existe")
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("em preparação")
  end
end
```

Criar `spec/system/booking_creation_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe "Criação de reserva", type: :system do
  it "cria a reserva e exibe o link para envio" do
    host = create(:host, password: "senha-segura-123")
    create(:property, host: host, name: "Chalé da Serra")
    create(:guest, host: host, name: "Carlos Hóspede")

    visit new_session_path
    fill_in "E-mail", with: host.email_address
    fill_in "Senha", with: "senha-segura-123"
    click_button "Entrar"

    click_link "Reservas"
    click_link "Nova reserva"
    select "Chalé da Serra", from: "Hospedagem"
    select "Carlos Hóspede", from: "Cliente"
    fill_in "Check-in", with: Date.current
    fill_in "Check-out", with: Date.current + 3
    click_button "Criar reserva"

    expect(page).to have_content("Reserva criada")
    expect(page).to have_content("/g/#{Booking.last.access_token}")
  end
end
```

- [ ] **Step 2: Rodar e ver falhar**

Run: `bundle exec rspec spec/requests/bookings_spec.rb spec/requests/public_guides_spec.rb spec/system/booking_creation_spec.rb`
Expected: FAIL (rotas inexistentes)

- [ ] **Step 3: Rotas, controllers, helper**

Em `config/routes.rb`, adicionar:

```ruby
resources :bookings, only: %i[index new create show] do
  member do
    patch :revoke
    patch :reissue
  end
end

get "g/:token", to: "public_guides#show", as: :public_guide
```

`app/controllers/bookings_controller.rb`:

```ruby
class BookingsController < ApplicationController
  def index
    bookings = Current.host.bookings.includes(:property, :guest)
    @current_bookings = bookings.within_window.recent_first
    @finished_bookings = bookings.finished.recent_first
  end

  def new
    @booking = Booking.new
  end

  def create
    @booking = Booking.new(booking_attributes)
    if @booking.save
      redirect_to @booking, notice: "Reserva criada. Envie o link ao hóspede."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def show
    @booking = Current.host.bookings.find(params[:id])
  end

  def revoke
    booking = Current.host.bookings.find(params[:id])
    booking.revoke!
    redirect_to booking, notice: "Link revogado. O hóspede perdeu o acesso."
  end

  def reissue
    booking = Current.host.bookings.find(params[:id])
    booking.reissue!
    redirect_to booking, notice: "Novo link gerado. O anterior deixou de funcionar."
  end

  private
    def booking_attributes
      permitted = params.expect(booking: [ :property_id, :guest_id, :check_in, :check_out ])
      {
        property: Current.host.properties.find(permitted[:property_id]),
        guest: Current.host.guests.find(permitted[:guest_id]),
        check_in: permitted[:check_in],
        check_out: permitted[:check_out]
      }
    end
end
```

`app/controllers/public_guides_controller.rb`:

```ruby
class PublicGuidesController < ApplicationController
  allow_unauthenticated_access

  # Placeholder do Subprojeto 3: resposta idêntica para qualquer token,
  # sem lookup — nada sobre a reserva pode vazar por aqui.
  def show
  end
end
```

`app/helpers/bookings_helper.rb`:

```ruby
module BookingsHelper
  def guide_link_for(booking)
    public_guide_url(token: booking.access_token)
  end

  def whatsapp_share_url(booking)
    message = "Olá, #{booking.guest.name}! Aqui está o guia digital da sua hospedagem " \
              "em #{booking.property.name}: #{guide_link_for(booking)}"
    "https://wa.me/55#{booking.guest.phone}?text=#{ERB::Util.url_encode(message)}"
  end
end
```

- [ ] **Step 4: Views e Stimulus**

`app/javascript/controllers/clipboard_controller.js`:

```javascript
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["source", "button"]

  async copy() {
    await navigator.clipboard.writeText(this.sourceTarget.value)
    this.buttonTarget.textContent = "Copiado!"
    setTimeout(() => { this.buttonTarget.textContent = "Copiar" }, 2000)
  }
}
```

`app/views/bookings/_form.html.erb`:

```erb
<%= form_with model: booking, class: "max-w-lg space-y-4" do |f| %>
  <%= render "shared/form_errors", record: booking %>
  <div>
    <%= f.label :property_id, "Hospedagem", class: "block text-sm font-medium" %>
    <%= f.collection_select :property_id, Current.host.properties.order(:name), :id, :name,
          { prompt: "Escolha a hospedagem" }, { required: true, class: "mt-1 w-full rounded-lg border-gray-300" } %>
  </div>
  <div>
    <%= f.label :guest_id, "Cliente", class: "block text-sm font-medium" %>
    <%= f.collection_select :guest_id, Current.host.guests.order(:name), :id, :name,
          { prompt: "Escolha o cliente" }, { required: true, class: "mt-1 w-full rounded-lg border-gray-300" } %>
  </div>
  <div class="grid grid-cols-2 gap-4">
    <div>
      <%= f.label :check_in, class: "block text-sm font-medium" %>
      <%= f.date_field :check_in, required: true, class: "mt-1 w-full rounded-lg border-gray-300" %>
    </div>
    <div>
      <%= f.label :check_out, class: "block text-sm font-medium" %>
      <%= f.date_field :check_out, required: true, class: "mt-1 w-full rounded-lg border-gray-300" %>
    </div>
  </div>
  <%= f.submit "Criar reserva", class: "rounded-lg bg-gray-900 px-4 py-2 font-medium text-white" %>
<% end %>
```

`app/views/bookings/new.html.erb`:

```erb
<h1 class="mb-6 text-2xl font-bold">Nova reserva</h1>
<% if Current.host.properties.none? || Current.host.guests.none? %>
  <p class="rounded-lg border border-dashed p-6 text-sm text-gray-600">
    Para criar uma reserva você precisa de pelo menos
    <%= link_to "uma hospedagem", properties_path, class: "underline" %> e
    <%= link_to "um cliente", guests_path, class: "underline" %> cadastrados.
  </p>
<% else %>
  <%= render "form", booking: @booking %>
<% end %>
```

`app/views/bookings/_list.html.erb`:

```erb
<% if bookings.none? %>
  <p class="rounded-lg border border-dashed p-6 text-center text-sm text-gray-500">Nenhuma reserva aqui.</p>
<% else %>
  <div class="space-y-2">
    <% bookings.each do |booking| %>
      <%= link_to booking_path(booking), class: "flex items-center justify-between rounded-lg border bg-white px-4 py-3 hover:shadow" do %>
        <div>
          <p class="font-medium"><%= booking.guest.name %> — <%= booking.property.name %></p>
          <p class="text-sm text-gray-500">
            <%= l booking.check_in %> a <%= l booking.check_out %>
          </p>
        </div>
        <% if booking.revoked? %>
          <span class="rounded bg-red-100 px-2 py-0.5 text-xs text-red-800">Link revogado</span>
        <% elsif booking.link_active? %>
          <span class="rounded bg-green-100 px-2 py-0.5 text-xs text-green-800">Link ativo</span>
        <% else %>
          <span class="rounded bg-gray-100 px-2 py-0.5 text-xs text-gray-600">Encerrada</span>
        <% end %>
      <% end %>
    <% end %>
  </div>
<% end %>
```

`app/views/bookings/index.html.erb`:

```erb
<div class="mb-6 flex items-center justify-between">
  <h1 class="text-2xl font-bold">Reservas</h1>
  <%= link_to "Nova reserva", new_booking_path,
        class: "rounded-lg bg-gray-900 px-4 py-2 text-sm font-medium text-white" %>
</div>

<h2 class="mb-2 text-sm font-semibold uppercase text-gray-500">Ativas e futuras</h2>
<%= render "list", bookings: @current_bookings %>

<h2 class="mb-2 mt-8 text-sm font-semibold uppercase text-gray-500">Encerradas</h2>
<%= render "list", bookings: @finished_bookings %>
```

`app/views/bookings/show.html.erb`:

```erb
<div class="mb-6">
  <h1 class="text-2xl font-bold">Reserva — <%= @booking.guest.name %></h1>
  <p class="text-gray-600">
    <%= @booking.property.name %> · <%= l @booking.check_in %> a <%= l @booking.check_out %>
    · CPF <%= @booking.guest.masked_cpf %>
  </p>
</div>

<div class="rounded-lg border bg-white p-4">
  <h2 class="mb-2 font-semibold">Link de acesso do hóspede</h2>
  <% if @booking.revoked? %>
    <p class="mb-3 text-sm text-red-700">Este link foi revogado. Gere um novo para restaurar o acesso.</p>
  <% elsif !@booking.link_active? %>
    <p class="mb-3 text-sm text-gray-600">A janela de acesso desta reserva terminou em <%= l @booking.accessible_until %>.</p>
  <% else %>
    <p class="mb-3 text-sm text-gray-600">Válido até <%= l @booking.accessible_until %> (check-out + margem).</p>
  <% end %>

  <div class="flex gap-2" data-controller="clipboard">
    <input type="text" readonly value="<%= guide_link_for(@booking) %>" data-clipboard-target="source"
           class="w-full rounded-lg border-gray-300 bg-gray-50 text-sm">
    <button type="button" data-action="clipboard#copy" data-clipboard-target="button"
            class="rounded-lg border px-4 py-2 text-sm">Copiar</button>
  </div>

  <div class="mt-4 flex flex-wrap gap-2">
    <%= link_to "Enviar por WhatsApp", whatsapp_share_url(@booking), target: "_blank", rel: "noopener",
          class: "rounded-lg bg-green-600 px-4 py-2 text-sm font-medium text-white" %>
    <% if @booking.revoked? %>
      <%= button_to "Gerar novo link", reissue_booking_path(@booking), method: :patch,
            class: "rounded-lg border px-4 py-2 text-sm" %>
    <% else %>
      <%= button_to "Revogar link", revoke_booking_path(@booking), method: :patch,
            class: "rounded-lg border border-red-300 px-4 py-2 text-sm text-red-700",
            form: { data: { turbo_confirm: "O hóspede perderá o acesso imediatamente. Revogar?" } } %>
      <%= button_to "Regenerar link", reissue_booking_path(@booking), method: :patch,
            class: "rounded-lg border px-4 py-2 text-sm",
            form: { data: { turbo_confirm: "O link atual deixará de funcionar. Continuar?" } } %>
    <% end %>
  </div>
</div>
```

`app/views/public_guides/show.html.erb`:

```erb
<div class="mx-auto mt-24 max-w-md text-center">
  <h1 class="text-2xl font-bold">Anfitriar</h1>
  <p class="mt-4 text-gray-600">O guia digital desta hospedagem está em preparação. Volte em breve!</p>
</div>
```

Em `app/views/layouts/_nav.html.erb`, adicionar após o link de categorias:

```erb
<%= link_to t("nav.bookings"), bookings_path, class: "text-gray-700 hover:text-gray-900" %>
```

- [ ] **Step 5: Rodar e ver passar**

Run: `bundle exec rspec && bin/rubocop`
Expected: PASS, sem ofensas

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "feat: telas de reservas com link, WhatsApp e regenerar"
```

---

### Task 14: Preview "ver como hóspede"

**Files:**
- Create: `app/controllers/properties/previews_controller.rb`, `app/views/properties/previews/show.html.erb`
- Modify: `config/routes.rb`, `app/views/properties/show.html.erb`, `app/views/bookings/show.html.erb` (links de preview)
- Test: `spec/requests/property_previews_spec.rb`

**Interfaces:**
- Consumes: `Property#visible_cards` (Task 10).
- Produces: rota `GET properties/:property_id/preview` (`property_preview_path`) — render bruto dos cards visíveis, autenticado como anfitrião, sem confirmação de CPF (o visual final é o Subprojeto 3).

- [ ] **Step 1: Escrever specs (falhando)**

Criar `spec/requests/property_previews_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe "Preview do guia", type: :request do
  let!(:host) { create(:host) }
  let!(:property) { create(:property, host: host) }

  before { sign_in host }

  it "mostra apenas cards preenchidos e não ocultos, em ordem" do
    wifi = create(:category, name: "Wi-Fi", position: 1)
    rules = create(:category, name: "Regras da casa", position: 2)
    phones = create(:category, name: "Telefones úteis", position: 3)
    Card.upsert_for(property, wifi, description: "<p>Rede: Casa</p>", position: 1)
    Card.upsert_for(property, rules, description: "<p>Sem festas</p>", position: 2, hidden: true)
    Card.upsert_for(property, phones, description: nil, position: 3)

    get property_preview_path(property)
    expect(response.body).to include("Wi-Fi")
    expect(response.body).to include("Rede: Casa")
    expect(response.body).not_to include("Sem festas")
    expect(response.body).not_to include("Telefones úteis")
  end

  it "exige login (não é a rota pública)" do
    delete session_path
    get property_preview_path(property)
    expect(response).to redirect_to(new_session_path)
  end

  it "rejeita hospedagem de outro anfitrião (404)" do
    other = create(:property)
    get property_preview_path(other)
    expect(response).to have_http_status(:not_found)
  end
end
```

- [ ] **Step 2: Rodar e ver falhar**

Run: `bundle exec rspec spec/requests/property_previews_spec.rb`
Expected: FAIL (rota inexistente)

- [ ] **Step 3: Implementar**

Em `config/routes.rb`, dentro do `scope module: :properties` (Task 11), adicionar:

```ruby
resource :preview, only: :show
```

`app/controllers/properties/previews_controller.rb`:

```ruby
class Properties::PreviewsController < ApplicationController
  def show
    @property = Current.host.properties.find(params[:property_id])
    @cards = @property.visible_cards
  end
end
```

`app/views/properties/previews/show.html.erb`:

```erb
<div class="mb-6">
  <p class="mb-2 rounded-lg bg-yellow-50 p-3 text-sm text-yellow-800">
    Pré-visualização bruta — o visual final do guia do hóspede chega no Subprojeto 3.
  </p>
  <h1 class="text-2xl font-bold"><%= @property.name %></h1>
  <p class="text-gray-600"><%= @property.address %></p>
</div>

<% if @cards.none? %>
  <p class="rounded-lg border border-dashed p-8 text-center text-gray-500">
    Nenhum card preenchido ainda. <%= link_to "Montar o guia", property_guide_path(@property), class: "underline" %>.
  </p>
<% else %>
  <div class="space-y-4">
    <% @cards.each do |card| %>
      <div class="rounded-lg border bg-white p-4">
        <h2 class="mb-2 font-semibold"><%= card.category.name %></h2>
        <div class="prose prose-sm max-w-none"><%= card.description %></div>
      </div>
    <% end %>
  </div>
<% end %>
```

Em `app/views/properties/show.html.erb`, no bloco do guia (Task 11), ao lado do link "Montar o guia":

```erb
<%= link_to "Ver como hóspede", property_preview_path(@property), class: "rounded-lg border px-4 py-2 text-sm" %>
```

Em `app/views/bookings/show.html.erb`, junto aos botões de ação do link:

```erb
<%= link_to "Ver como hóspede", property_preview_path(@booking.property), class: "rounded-lg border px-4 py-2 text-sm" %>
```

- [ ] **Step 4: Rodar e ver passar**

Run: `bundle exec rspec && bin/rubocop`
Expected: PASS, sem ofensas

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "feat: preview do guia como hóspede"
```

---

### Task 15: Conta do anfitrião, navegação final e fluxo ponta a ponta

**Files:**
- Create: `app/controllers/accounts_controller.rb`, `app/views/accounts/show.html.erb`, `app/helpers/subscriptions_helper.rb`
- Modify: `config/routes.rb`, `app/views/layouts/_nav.html.erb`
- Test: `spec/requests/accounts_spec.rb`, `spec/system/host_journey_spec.rb`

**Interfaces:**
- Consumes: `Subscription#trial_days_left` (Task 4); tudo anterior para o fluxo E2E.
- Produces: rota `resource :account, only: %i[show update]`; `subscription_status_label(subscription)` → String em PT.

- [ ] **Step 1: Escrever specs (falhando)**

Criar `spec/requests/accounts_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe "Conta", type: :request do
  let!(:host) { create(:host) }

  before do
    create(:subscription, host: host, plan: create(:plan, name: "Pro Teste"), trial_ends_at: 5.days.from_now)
    sign_in host
  end

  it "mostra dados e status da assinatura" do
    get account_path
    expect(response.body).to include(host.name)
    expect(response.body).to include("Pro Teste")
    expect(response.body).to include("Período de teste")
    expect(response.body).to include("5 dias")
  end

  it "atualiza os dados do anfitrião" do
    patch account_path, params: { host: { name: "Novo Nome", phone: "11999998888", email_address: host.email_address } }
    expect(response).to redirect_to(account_path)
    expect(host.reload.name).to eq("Novo Nome")
  end

  it "reexibe com erros quando inválido" do
    patch account_path, params: { host: { name: "", phone: "1", email_address: "x" } }
    expect(response).to have_http_status(:unprocessable_entity)
  end
end
```

Criar `spec/system/host_journey_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe "Jornada do anfitrião", type: :system do
  before do
    create(:plan, slug: "pro", name: "Pro")
    create(:category, name: "Wi-Fi", position: 1)
  end

  it "cadastra, cria hospedagem, cliente e reserva com link" do
    visit new_registration_path
    fill_in "Nome", with: "Ana Anfitriã"
    fill_in "E-mail", with: "ana@example.com"
    fill_in "Telefone", with: "11987654321"
    fill_in "Senha", with: "senha-segura-123"
    fill_in "Confirmação de senha", with: "senha-segura-123"
    click_button "Criar conta"
    expect(page).to have_content("período de teste")

    click_link "Nova hospedagem"
    fill_in "Nome", with: "Chalé da Serra"
    fill_in "Endereço", with: "Estrada da Serra, 42"
    click_button "Criar Hospedagem"
    expect(page).to have_content("Hospedagem criada")

    click_link "Clientes"
    click_link "Novo cliente"
    fill_in "Nome", with: "Carlos Hóspede"
    fill_in "CPF", with: "390.533.447-05"
    fill_in "Telefone", with: "(11) 91234-5678"
    click_button "Criar Cliente"
    expect(page).to have_content("Cliente cadastrado")

    click_link "Reservas"
    click_link "Nova reserva"
    select "Chalé da Serra", from: "Hospedagem"
    select "Carlos Hóspede", from: "Cliente"
    fill_in "Check-in", with: Date.current
    fill_in "Check-out", with: Date.current + 3
    click_button "Criar reserva"

    expect(page).to have_content("Reserva criada")
    expect(page).to have_content("/g/#{Booking.last.access_token}")
  end
end
```

(Se os textos dos botões de submit gerados pelo `form_with` divergirem — ex.: "Criar Hospedagem" —, ajustar o spec ao texto real em vez de forçar o texto na view.)

- [ ] **Step 2: Rodar e ver falhar**

Run: `bundle exec rspec spec/requests/accounts_spec.rb spec/system/host_journey_spec.rb`
Expected: FAIL (rota `account_path` inexistente)

- [ ] **Step 3: Implementar**

Em `config/routes.rb`, adicionar `resource :account, only: %i[show update]`.

`app/helpers/subscriptions_helper.rb`:

```ruby
module SubscriptionsHelper
  STATUS_LABELS = {
    "trial" => "Período de teste",
    "active" => "Ativa",
    "past_due" => "Pagamento pendente",
    "canceled" => "Cancelada"
  }.freeze

  def subscription_status_label(subscription)
    STATUS_LABELS.fetch(subscription.status, subscription.status)
  end
end
```

`app/controllers/accounts_controller.rb`:

```ruby
class AccountsController < ApplicationController
  def show
    @host = Current.host
    @subscription = @host.subscription
  end

  def update
    @host = Current.host
    if @host.update(params.expect(host: [ :name, :phone, :email_address ]))
      redirect_to account_path, notice: "Dados atualizados."
    else
      @subscription = @host.subscription
      render :show, status: :unprocessable_entity
    end
  end
end
```

`app/views/accounts/show.html.erb`:

```erb
<h1 class="mb-6 text-2xl font-bold">Minha conta</h1>

<% if @subscription %>
  <div class="mb-6 rounded-lg border bg-white p-4">
    <h2 class="font-semibold">Plano <%= @subscription.plan.name %></h2>
    <p class="text-sm text-gray-600">
      Status: <%= subscription_status_label(@subscription) %>
      <% if @subscription.trial? %>
        — <%= @subscription.trial_days_left %> dias restantes
      <% end %>
    </p>
  </div>
<% end %>

<%= form_with model: @host, url: account_path, method: :patch, class: "max-w-lg space-y-4" do |f| %>
  <%= render "shared/form_errors", record: @host %>
  <div>
    <%= f.label :name, class: "block text-sm font-medium" %>
    <%= f.text_field :name, required: true, class: "mt-1 w-full rounded-lg border-gray-300" %>
  </div>
  <div>
    <%= f.label :email_address, class: "block text-sm font-medium" %>
    <%= f.email_field :email_address, required: true, class: "mt-1 w-full rounded-lg border-gray-300" %>
  </div>
  <div>
    <%= f.label :phone, class: "block text-sm font-medium" %>
    <%= f.telephone_field :phone, required: true, class: "mt-1 w-full rounded-lg border-gray-300" %>
  </div>
  <%= f.submit "Salvar", class: "rounded-lg bg-gray-900 px-4 py-2 font-medium text-white" %>
<% end %>
```

Em `app/views/layouts/_nav.html.erb`, adicionar após o link de reservas:

```erb
<%= link_to t("nav.account"), account_path, class: "text-gray-700 hover:text-gray-900" %>
```

- [ ] **Step 4: Rodar TUDO e ver passar**

Run: `bundle exec rspec && bin/rubocop && bin/brakeman --no-pager`
Expected: suíte inteira PASS, sem ofensas, Brakeman sem warnings novos

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "feat: tela de conta e navegação final"
```

---

## Encerramento

Ao concluir a Task 15, usar a skill `superpowers:finishing-a-development-branch`: a suíte completa deve estar verde; a branch `feat/subprojeto-1-fundacao` fica pronta para merge local em `main` (push/PR dependem de o usuário definir o remote — o repo GitHub atual contém a iteração anterior).



