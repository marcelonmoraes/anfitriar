# Dashboard do Anfitrião — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Construir o dashboard do Anfitrião com KPIs financeiros (Ocupação, Receita, ADR, RevPAR), gráficos ApexCharts e timeline operacional de Hoje/Amanhã.

**Architecture:** Uma nova coluna `total_price_cents` em `bookings` alimenta os KPIs. O cálculo vive em dois lugares: métodos de classe em `Booking` (queries e séries) e um PORO `Dashboard::Metrics` (resolve período, monta KPIs). O `DashboardController` delega tudo para o PORO e monta a timeline. As tabs de performance vivem num Turbo Frame que recarrega ao trocar período/tab.

**Tech Stack:** Rails 8.1, Ruby 4.0.5, PostgreSQL, Hotwire (Turbo + Stimulus), Tailwind CSS v4, importmap, ApexCharts, RSpec + FactoryBot.

## Global Constraints

- Ruby 4.0.5, Rails 8.1.3.1, PostgreSQL. Nenhuma gem nova.
- ApexCharts entra via `bin/importmap pin apexcharts --download` (arquivo em `vendor/javascript/`). A CSP do projeto é `default_src :self` — CDN não funciona.
- Idioma da interface: **português do Brasil**. Todo texto visível ao usuário em pt-BR.
- Estilo visual: monocromático charcoal `#111827`, bordas 1px `#e5e7eb`, **zero sombras** na área autenticada. Seguir `DESIGN.md`.
- Multi-tenancy: **toda** query de dados do anfitrião parte de `Current.host`. Nunca `Booking.all` ou `Property.all` num contexto de host.
- Testes: RSpec com `type: :request` / `type: :model` explícito (o projeto não usa `infer_spec_type_from_file_location`).
- Rodar `bin/rubocop` antes de cada commit. O projeto usa `rubocop-rails-omakase`.
- Não existe infraestrutura de system test (sem `spec/system/`, sem driver Capybara). Não criar.
- Commits em português, no estilo do repositório (`feat:`, `fix:`, `docs:`, `test:`).

---

### Task 1: Coluna de preço na reserva

**Files:**
- Create: `db/migrate/<timestamp>_add_total_price_cents_to_bookings.rb`
- Modify: `app/models/booking.rb`
- Modify: `spec/factories/bookings.rb`
- Test: `spec/models/booking_spec.rb`

**Interfaces:**
- Consumes: nada (primeira task)
- Produces:
  - Coluna `bookings.total_price_cents` (integer, null: false, default: 0)
  - `Booking#total_price` → String com 2 casas decimais (ex: `"300.00"`)
  - `Booking#total_price=(value)` → aceita String formatada em pt-BR (`"R$ 1.200,00"`) e grava centavos
  - `Booking#nights` → Integer, noites entre check_in e check_out
  - Factory trait `:priced` → `total_price_cents = 30_000`

- [ ] **Step 1: Gerar a migration**

```bash
bin/rails generate migration AddTotalPriceCentsToBookings
```

Substituir o conteúdo do arquivo gerado por:

```ruby
class AddTotalPriceCentsToBookings < ActiveRecord::Migration[8.1]
  def change
    add_column :bookings, :total_price_cents, :integer, null: false, default: 0
  end
end
```

- [ ] **Step 2: Rodar a migration**

```bash
bin/rails db:migrate
```

Verificar que `db/schema.rb` ganhou `t.integer "total_price_cents", default: 0, null: false` dentro de `create_table "bookings"`.

- [ ] **Step 3: Adicionar o trait à factory**

Em `spec/factories/bookings.rb`, dentro do bloco `factory :booking do`, após a linha `check_out { Date.current + 3 }`:

```ruby
    trait :priced do
      total_price_cents { 30_000 }
    end
```

- [ ] **Step 4: Escrever os testes que falham**

Adicionar ao final de `spec/models/booking_spec.rb`, antes do `end` final:

```ruby
  describe "preço" do
    it "começa zerado" do
      expect(create(:booking).total_price_cents).to eq(0)
    end

    it "aceita valor formatado em reais e guarda centavos" do
      booking = build(:booking)

      booking.total_price = "R$ 1.200,00"
      expect(booking.total_price_cents).to eq(120_000)

      booking.total_price = "300,50"
      expect(booking.total_price_cents).to eq(30_050)

      booking.total_price = "1200"
      expect(booking.total_price_cents).to eq(120_000)
    end

    it "trata valor em branco como zero" do
      booking = build(:booking, total_price_cents: 5_000)
      booking.total_price = ""
      expect(booking.total_price_cents).to eq(0)
    end

    it "lê centavos como string com duas casas" do
      expect(build(:booking, total_price_cents: 30_050).total_price).to eq("300.50")
    end

    it "conta as noites da reserva" do
      booking = build(:booking, check_in: Date.new(2026, 8, 10), check_out: Date.new(2026, 8, 13))
      expect(booking.nights).to eq(3)
    end
  end
```

- [ ] **Step 5: Rodar os testes para ver falhar**

```bash
bundle exec rspec spec/models/booking_spec.rb -e "preço"
```

Esperado: FAIL com `NoMethodError: undefined method 'total_price=' for an instance of Booking`.

- [ ] **Step 6: Implementar no model**

Em `app/models/booking.rb`, adicionar após o método `accessible_until` (antes de `def revoked?`):

```ruby
  # O formulário trabalha em reais; o banco guarda centavos.
  def total_price
    format("%.2f", total_price_cents / 100.0)
  end

  def total_price=(value)
    digits = value.to_s.gsub(/[^\d,.]/, "").tr(",", ".")
    self.total_price_cents = digits.blank? ? 0 : (digits.to_f * 100).round
  end

  def nights
    (check_out - check_in).to_i
  end
```

Atenção: `"1.200,00".gsub(/[^\d,.]/, "")` vira `"1.200,00"` e `.tr(",", ".")` vira `"1.200.00"`, cujo `to_f` é `1.2`. Isso está errado. A implementação correta remove o separador de milhar antes:

```ruby
  def total_price=(value)
    normalized = value.to_s.gsub(/[^\d,.]/, "")
    normalized = if normalized.include?(",")
      normalized.delete(".").tr(",", ".")
    else
      normalized
    end
    self.total_price_cents = normalized.blank? ? 0 : (normalized.to_f * 100).round
  end
```

Usar esta segunda versão.

- [ ] **Step 7: Rodar os testes para ver passar**

```bash
bundle exec rspec spec/models/booking_spec.rb
```

Esperado: PASS, todos os exemplos (os antigos e os 5 novos).

- [ ] **Step 8: Rodar o lint**

```bash
bin/rubocop app/models/booking.rb spec/models/booking_spec.rb spec/factories/bookings.rb
```

Esperado: `no offenses detected`. Corrigir o que aparecer.

- [ ] **Step 9: Commit**

```bash
git add db/migrate db/schema.rb app/models/booking.rb spec/models/booking_spec.rb spec/factories/bookings.rb
git commit -m "feat: adiciona preço total à reserva"
```

---

### Task 2: KPIs de ocupação e receita no model

**Files:**
- Modify: `app/models/booking.rb`
- Test: `spec/models/booking_spec.rb`

**Interfaces:**
- Consumes: `Booking#nights`, `bookings.total_price_cents` (Task 1)
- Produces (todos são métodos de classe, chamáveis em qualquer relation — ex: `Current.host.bookings.occupancy_rate(...)`):
  - `Booking.active` → scope, reservas não revogadas
  - `Booking.within_range(start_date, end_date)` → scope, reservas com `check_in` no intervalo
  - `Booking.overlapping(start_date, end_date)` → scope, reservas que tocam o intervalo
  - `Booking.booked_nights(start_date, end_date)` → Integer
  - `Booking.available_nights(start_date, end_date, properties_count)` → Integer
  - `Booking.revenue_in_range(start_date, end_date)` → Integer (centavos)
  - `Booking.occupancy_rate(start_date, end_date, properties_count)` → Float (0.0 a 100.0, 1 casa)
  - `Booking.adr(start_date, end_date)` → Float (reais, 2 casas)
  - `Booking.revpar(start_date, end_date, properties_count)` → Float (reais, 2 casas)

**Contexto para quem implementa:** `within_range` (por `check_in`) serve para **receita** — o valor da reserva é atribuído à data de check-in. `overlapping` serve para **ocupação** — uma reserva que atravessa a borda do período deve contar só as noites que caem dentro dele.

- [ ] **Step 1: Escrever os testes que falham**

Adicionar ao final de `spec/models/booking_spec.rb`, antes do `end` final:

```ruby
  describe "indicadores" do
    let(:host) { create(:host) }
    let(:property) { create(:property, host: host) }
    let(:guest) { create(:guest, host: host) }
    let(:starts_on) { Date.new(2026, 8, 1) }
    let(:ends_on) { Date.new(2026, 8, 10) }

    def booking_for(check_in:, check_out:, cents: 0)
      create(:booking, property: property, guest: guest,
             check_in: check_in, check_out: check_out, total_price_cents: cents)
    end

    it "soma a receita das reservas com check-in no período" do
      booking_for(check_in: starts_on, check_out: starts_on + 2, cents: 30_000)
      booking_for(check_in: ends_on, check_out: ends_on + 1, cents: 10_000)
      booking_for(check_in: ends_on + 5, check_out: ends_on + 7, cents: 99_900)

      expect(host.bookings.revenue_in_range(starts_on, ends_on)).to eq(40_000)
    end

    it "ignora reservas revogadas na receita" do
      booking_for(check_in: starts_on, check_out: starts_on + 2, cents: 30_000).revoke!

      expect(host.bookings.revenue_in_range(starts_on, ends_on)).to eq(0)
    end

    it "recorta noites de reservas que atravessam as bordas do período" do
      booking_for(check_in: starts_on - 3, check_out: starts_on + 2)
      booking_for(check_in: ends_on - 1, check_out: ends_on + 4)

      # 2 noites (dias 1 e 2) + 2 noites (dias 9 e 10)
      expect(host.bookings.booked_nights(starts_on, ends_on)).to eq(4)
    end

    it "calcula a taxa de ocupação sobre as noites disponíveis" do
      booking_for(check_in: starts_on, check_out: starts_on + 5)

      # 5 noites ocupadas / (1 propriedade * 10 dias) = 50%
      expect(host.bookings.occupancy_rate(starts_on, ends_on, 1)).to eq(50.0)
    end

    it "devolve zero de ocupação sem propriedades" do
      expect(host.bookings.occupancy_rate(starts_on, ends_on, 0)).to eq(0.0)
    end

    it "calcula a diária média sobre as noites vendidas" do
      booking_for(check_in: starts_on, check_out: starts_on + 2, cents: 30_000)

      expect(host.bookings.adr(starts_on, ends_on)).to eq(150.0)
    end

    it "ignora reservas sem preço na diária média" do
      booking_for(check_in: starts_on, check_out: starts_on + 2, cents: 30_000)
      booking_for(check_in: starts_on, check_out: starts_on + 4, cents: 0)

      expect(host.bookings.adr(starts_on, ends_on)).to eq(150.0)
    end

    it "devolve zero de diária média sem reservas com preço" do
      expect(host.bookings.adr(starts_on, ends_on)).to eq(0.0)
    end

    it "calcula o revpar sobre as noites disponíveis" do
      booking_for(check_in: starts_on, check_out: starts_on + 2, cents: 30_000)

      # R$ 300 / (1 propriedade * 10 dias) = R$ 30,00
      expect(host.bookings.revpar(starts_on, ends_on, 1)).to eq(30.0)
    end

    it "devolve zero de revpar sem propriedades" do
      expect(host.bookings.revpar(starts_on, ends_on, 0)).to eq(0.0)
    end
  end
```

- [ ] **Step 2: Rodar os testes para ver falhar**

```bash
bundle exec rspec spec/models/booking_spec.rb -e "indicadores"
```

Esperado: FAIL com `NoMethodError: undefined method 'revenue_in_range'`.

- [ ] **Step 3: Implementar os scopes**

Em `app/models/booking.rb`, adicionar após o scope `recent_first`:

```ruby
  scope :active, -> { where(revoked_at: nil) }
  scope :within_range, ->(start_date, end_date) { where(check_in: start_date..end_date) }
  # Reservas que tocam o período, mesmo começando antes ou terminando depois.
  scope :overlapping, ->(start_date, end_date) {
    where(check_in: ..end_date).where(check_out: start_date..)
  }
```

- [ ] **Step 4: Implementar os métodos de KPI**

Ainda em `app/models/booking.rb`, adicionar após os scopes (antes de `validates`):

```ruby
  # Noites ocupadas dentro do período, recortadas nas bordas: uma reserva que
  # começa antes ou termina depois conta só o trecho que cai no intervalo.
  def self.booked_nights(start_date, end_date)
    active.overlapping(start_date, end_date).sum do |booking|
      first_night = [ booking.check_in, start_date ].max
      last_night = [ booking.check_out, end_date + 1 ].min
      [ (last_night - first_night).to_i, 0 ].max
    end
  end

  def self.available_nights(start_date, end_date, properties_count)
    properties_count * ((end_date - start_date).to_i + 1)
  end

  def self.revenue_in_range(start_date, end_date)
    active.within_range(start_date, end_date).sum(:total_price_cents)
  end

  def self.occupancy_rate(start_date, end_date, properties_count)
    capacity = available_nights(start_date, end_date, properties_count)
    return 0.0 if capacity.zero?

    (booked_nights(start_date, end_date).to_f / capacity * 100).round(1)
  end

  # Diária média: receita dividida pelas noites efetivamente vendidas.
  def self.adr(start_date, end_date)
    priced = active.within_range(start_date, end_date).where("total_price_cents > 0")
    sold_nights = priced.sum(&:nights)
    return 0.0 if sold_nights.zero?

    (priced.sum(:total_price_cents).to_f / sold_nights / 100).round(2)
  end

  # Receita por noite disponível, ocupada ou não.
  def self.revpar(start_date, end_date, properties_count)
    capacity = available_nights(start_date, end_date, properties_count)
    return 0.0 if capacity.zero?

    (revenue_in_range(start_date, end_date).to_f / 100 / capacity).round(2)
  end
```

- [ ] **Step 5: Rodar os testes para ver passar**

```bash
bundle exec rspec spec/models/booking_spec.rb
```

Esperado: PASS em todos os exemplos.

- [ ] **Step 6: Rodar o lint e commitar**

```bash
bin/rubocop app/models/booking.rb spec/models/booking_spec.rb
git add app/models/booking.rb spec/models/booking_spec.rb
git commit -m "feat: calcula ocupação, receita, diária média e revpar"
```

---

### Task 3: Séries temporais para os gráficos

**Files:**
- Modify: `app/models/booking.rb`
- Test: `spec/models/booking_spec.rb`

**Interfaces:**
- Consumes: scopes `active`, `within_range`, `overlapping` (Task 2)
- Produces:
  - `Booking.bucket_key(date, group_unit)` → Date; `group_unit` é `:day`, `:week` ou `:month`
  - `Booking.revenue_series(start_date, end_date, group_unit)` → `Hash{Date => Integer}` (centavos)
  - `Booking.occupancy_series(start_date, end_date, group_unit, properties_count)` → `Hash{Date => Float}` (percentual)

**Contexto:** ambas as séries devem devolver **todos** os buckets do período, inclusive os zerados — senão o gráfico fica com buracos. A ocupação distribui as noites de cada reserva pelos dias que ela cobre, depois agrupa.

- [ ] **Step 1: Escrever os testes que falham**

Adicionar ao final de `spec/models/booking_spec.rb`, antes do `end` final:

```ruby
  describe "séries para gráficos" do
    let(:host) { create(:host) }
    let(:property) { create(:property, host: host) }
    let(:guest) { create(:guest, host: host) }
    let(:starts_on) { Date.new(2026, 8, 1) }
    let(:ends_on) { Date.new(2026, 8, 5) }

    def booking_for(check_in:, check_out:, cents: 0)
      create(:booking, property: property, guest: guest,
             check_in: check_in, check_out: check_out, total_price_cents: cents)
    end

    it "devolve um bucket por dia, incluindo os zerados" do
      booking_for(check_in: Date.new(2026, 8, 3), check_out: Date.new(2026, 8, 4), cents: 20_000)

      series = host.bookings.revenue_series(starts_on, ends_on, :day)

      expect(series.keys).to eq((starts_on..ends_on).to_a)
      expect(series[Date.new(2026, 8, 3)]).to eq(20_000)
      expect(series[Date.new(2026, 8, 1)]).to eq(0)
    end

    it "agrupa receita por mês" do
      booking_for(check_in: Date.new(2026, 8, 3), check_out: Date.new(2026, 8, 4), cents: 20_000)
      booking_for(check_in: Date.new(2026, 9, 3), check_out: Date.new(2026, 9, 4), cents: 10_000)

      series = host.bookings.revenue_series(starts_on, Date.new(2026, 9, 30), :month)

      expect(series[Date.new(2026, 8, 1)]).to eq(20_000)
      expect(series[Date.new(2026, 9, 1)]).to eq(10_000)
    end

    it "distribui as noites da reserva pelos dias que ela cobre" do
      booking_for(check_in: Date.new(2026, 8, 2), check_out: Date.new(2026, 8, 4))

      series = host.bookings.occupancy_series(starts_on, ends_on, :day, 1)

      expect(series[Date.new(2026, 8, 1)]).to eq(0.0)
      expect(series[Date.new(2026, 8, 2)]).to eq(100.0)
      expect(series[Date.new(2026, 8, 3)]).to eq(100.0)
      expect(series[Date.new(2026, 8, 4)]).to eq(0.0)
    end

    it "devolve zero de ocupação sem propriedades" do
      series = host.bookings.occupancy_series(starts_on, ends_on, :day, 0)

      expect(series.values).to all(eq(0.0))
    end
  end
```

- [ ] **Step 2: Rodar os testes para ver falhar**

```bash
bundle exec rspec spec/models/booking_spec.rb -e "séries para gráficos"
```

Esperado: FAIL com `NoMethodError: undefined method 'revenue_series'`.

- [ ] **Step 3: Implementar as séries**

Em `app/models/booking.rb`, adicionar após o método `revpar`:

```ruby
  # Data que representa o balde do gráfico: o próprio dia, o início da semana
  # ou o início do mês.
  def self.bucket_key(date, group_unit)
    case group_unit
    when :day then date
    when :week then date.beginning_of_week
    else date.beginning_of_month
    end
  end

  # Todos os baldes do período aparecem, mesmo zerados, para o gráfico não
  # ficar com buracos.
  def self.revenue_series(start_date, end_date, group_unit)
    buckets = {}
    (start_date..end_date).each { |date| buckets[bucket_key(date, group_unit)] ||= 0 }

    active.within_range(start_date, end_date).each do |booking|
      buckets[bucket_key(booking.check_in, group_unit)] += booking.total_price_cents
    end

    buckets
  end

  def self.occupancy_series(start_date, end_date, group_unit, properties_count)
    nights_per_day = Hash.new(0)
    active.overlapping(start_date, end_date).each do |booking|
      (booking.check_in...booking.check_out).each { |date| nights_per_day[date] += 1 }
    end

    buckets = {}
    (start_date..end_date).each do |date|
      key = bucket_key(date, group_unit)
      buckets[key] ||= { nights: 0, days: 0 }
      buckets[key][:nights] += nights_per_day[date]
      buckets[key][:days] += 1
    end

    buckets.transform_values do |data|
      capacity = data[:days] * properties_count
      capacity.zero? ? 0.0 : (data[:nights].to_f / capacity * 100).round(1)
    end
  end
```

- [ ] **Step 4: Rodar os testes para ver passar**

```bash
bundle exec rspec spec/models/booking_spec.rb
```

Esperado: PASS em todos os exemplos.

- [ ] **Step 5: Rodar o lint e commitar**

```bash
bin/rubocop app/models/booking.rb spec/models/booking_spec.rb
git add app/models/booking.rb spec/models/booking_spec.rb
git commit -m "feat: monta séries de receita e ocupação para os gráficos"
```

---

### Task 4: PORO Dashboard::Metrics

**Files:**
- Create: `app/models/dashboard/metrics.rb`
- Test: `spec/models/dashboard/metrics_spec.rb`

**Interfaces:**
- Consumes: todos os métodos de KPI e série de `Booking` (Tasks 2 e 3)
- Produces:
  - `Dashboard::Metrics.new(host, period)` — `period` é String ou nil; inválido cai para `"30d"`
  - `Dashboard::Metrics::PERIODS` → `%w[7d 30d 90d 12m year]`
  - `#period` → String
  - `#date_range` → `Range<Date>`
  - `#group_unit` → `:day`, `:week` ou `:month`
  - `#properties_count` → Integer
  - `#kpis` → `{ occupancy: Float, revenue: Integer (centavos), adr: Float, revpar: Float }`
  - `#series` → `{ revenue: Hash{Date=>Integer}, occupancy: Hash{Date=>Float} }`
  - `#revenue_change_percentage` → Float ou `nil` (quando o período anterior teve receita zero)

- [ ] **Step 1: Escrever os testes que falham**

Criar `spec/models/dashboard/metrics_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe Dashboard::Metrics, type: :model do
  let(:host) { create(:host) }
  let!(:property) { create(:property, host: host) }
  let(:guest) { create(:guest, host: host) }

  def booking_for(check_in:, check_out:, cents: 0)
    create(:booking, property: property, guest: guest,
           check_in: check_in, check_out: check_out, total_price_cents: cents)
  end

  describe "período" do
    it "usa 30 dias por padrão" do
      metrics = described_class.new(host, nil)

      expect(metrics.period).to eq("30d")
      expect(metrics.date_range).to eq((29.days.ago.to_date..Date.current))
      expect(metrics.group_unit).to eq(:day)
    end

    it "ignora período desconhecido" do
      expect(described_class.new(host, "sempre").period).to eq("30d")
    end

    it "agrupa por semana em 90 dias" do
      metrics = described_class.new(host, "90d")

      expect(metrics.date_range).to eq((89.days.ago.to_date..Date.current))
      expect(metrics.group_unit).to eq(:week)
    end

    it "agrupa por mês em 12 meses e no ano" do
      expect(described_class.new(host, "12m").group_unit).to eq(:month)
      expect(described_class.new(host, "year").group_unit).to eq(:month)
      expect(described_class.new(host, "year").date_range)
        .to eq((Date.current.beginning_of_year..Date.current.end_of_year))
    end
  end

  describe "indicadores" do
    it "monta os quatro kpis" do
      booking_for(check_in: Date.current, check_out: Date.current + 2, cents: 30_000)

      kpis = described_class.new(host, "30d").kpis

      expect(kpis[:revenue]).to eq(30_000)
      expect(kpis[:adr]).to eq(150.0)
      expect(kpis[:occupancy]).to be > 0
      expect(kpis[:revpar]).to be > 0
    end

    it "não considera reservas de outro anfitrião" do
      create(:booking, :priced)

      expect(described_class.new(host, "30d").kpis[:revenue]).to eq(0)
    end

    it "conta as propriedades do anfitrião" do
      expect(described_class.new(host, "30d").properties_count).to eq(1)
    end
  end

  describe "variação de receita" do
    it "compara com o período anterior de mesmo tamanho" do
      booking_for(check_in: Date.current, check_out: Date.current + 1, cents: 20_000)
      booking_for(check_in: 40.days.ago.to_date, check_out: 39.days.ago.to_date, cents: 10_000)

      expect(described_class.new(host, "30d").revenue_change_percentage).to eq(100.0)
    end

    it "devolve nil quando o período anterior não teve receita" do
      booking_for(check_in: Date.current, check_out: Date.current + 1, cents: 20_000)

      expect(described_class.new(host, "30d").revenue_change_percentage).to be_nil
    end
  end

  describe "séries" do
    it "devolve receita e ocupação com um ponto por dia" do
      series = described_class.new(host, "7d").series

      expect(series[:revenue].size).to eq(7)
      expect(series[:occupancy].size).to eq(7)
    end
  end
end
```

- [ ] **Step 2: Rodar os testes para ver falhar**

```bash
bundle exec rspec spec/models/dashboard/metrics_spec.rb
```

Esperado: FAIL com `NameError: uninitialized constant Dashboard`.

- [ ] **Step 3: Implementar o PORO**

Criar `app/models/dashboard/metrics.rb`. Seguir o estilo dos objetos em `app/models/asaas/`: `# frozen_string_literal: true` no topo e módulo externo aninhado (não a forma compacta `class Dashboard::Metrics`).

```ruby
# frozen_string_literal: true

module Dashboard
  # Resolve o período escolhido no painel e monta os indicadores e séries a
  # partir das reservas do anfitrião.
  class Metrics
    PERIODS = %w[7d 30d 90d 12m year].freeze
    DEFAULT_PERIOD = "30d"

    attr_reader :period, :date_range, :group_unit

    def initialize(host, period)
      @host = host
      @period = PERIODS.include?(period) ? period : DEFAULT_PERIOD
      @date_range = build_date_range
      @group_unit = build_group_unit
    end

    def properties_count
      @properties_count ||= @host.properties.count
    end

    def kpis
      @kpis ||= {
        occupancy: bookings.occupancy_rate(starts_on, ends_on, properties_count),
        revenue: bookings.revenue_in_range(starts_on, ends_on),
        adr: bookings.adr(starts_on, ends_on),
        revpar: bookings.revpar(starts_on, ends_on, properties_count)
      }
    end

    def series
      @series ||= {
        revenue: bookings.revenue_series(starts_on, ends_on, group_unit),
        occupancy: bookings.occupancy_series(starts_on, ends_on, group_unit, properties_count)
      }
    end

    # Sem base de comparação, mostrar "+100%" mentiria sobre o crescimento.
    def revenue_change_percentage
      return nil if previous_revenue.zero?

      ((kpis[:revenue] - previous_revenue).to_f / previous_revenue * 100).round(1)
    end

    private
      def bookings
        @host.bookings
      end

      def starts_on
        date_range.begin
      end

      def ends_on
        date_range.end
      end

      def previous_revenue
        @previous_revenue ||= begin
          span = (ends_on - starts_on).to_i + 1
          bookings.revenue_in_range(starts_on - span, starts_on - 1)
        end
      end

      def build_date_range
        case @period
        when "7d" then 6.days.ago.to_date..Date.current
        when "30d" then 29.days.ago.to_date..Date.current
        when "90d" then 89.days.ago.to_date..Date.current
        when "12m" then 12.months.ago.to_date..Date.current
        when "year" then Date.current.beginning_of_year..Date.current.end_of_year
        end
      end

      def build_group_unit
        case @period
        when "7d", "30d" then :day
        when "90d" then :week
        else :month
        end
      end
  end
end
```

- [ ] **Step 4: Rodar os testes para ver passar**

```bash
bundle exec rspec spec/models/dashboard/metrics_spec.rb
```

Esperado: PASS em todos os exemplos.

- [ ] **Step 5: Conferir o autoload**

```bash
bin/rails zeitwerk:check
```

Esperado: `All is good!`. Se reclamar do nome da constante, conferir se o arquivo está em `app/models/dashboard/metrics.rb` e define `Dashboard::Metrics`.

- [ ] **Step 6: Rodar o lint e commitar**

```bash
bin/rubocop app/models/dashboard spec/models/dashboard
git add app/models/dashboard spec/models/dashboard
git commit -m "feat: adiciona objeto de métricas do painel"
```

---

### Task 5: Preço no formulário de reserva

**Files:**
- Modify: `app/controllers/bookings_controller.rb`
- Modify: `app/views/bookings/_form.html.erb`
- Modify: `app/views/bookings/show.html.erb`
- Test: `spec/requests/bookings_spec.rb`

**Interfaces:**
- Consumes: `Booking#total_price=` (Task 1)
- Produces: reservas criadas com preço via formulário; preço visível na página da reserva

- [ ] **Step 1: Escrever o teste que falha**

Adicionar em `spec/requests/bookings_spec.rb`, antes do `end` final:

```ruby
  it "grava e exibe o preço total da reserva" do
    post bookings_path, params: { booking: {
      property_id: property.id, guest_id: guest.id,
      check_in: Date.current, check_out: Date.current + 3,
      total_price: "1.200,00"
    } }

    expect(Booking.last.total_price_cents).to eq(120_000)

    follow_redirect!
    expect(response.body).to include("1.200,00")
  end

  it "aceita reserva sem preço informado" do
    post bookings_path, params: { booking: {
      property_id: property.id, guest_id: guest.id,
      check_in: Date.current, check_out: Date.current + 3,
      total_price: ""
    } }

    expect(Booking.last.total_price_cents).to eq(0)
  end
```

- [ ] **Step 2: Rodar o teste para ver falhar**

```bash
bundle exec rspec spec/requests/bookings_spec.rb -e "grava e exibe o preço"
```

Esperado: FAIL — `total_price_cents` fica 0 porque o parâmetro não é permitido.

- [ ] **Step 3: Permitir o parâmetro no controller**

Em `app/controllers/bookings_controller.rb`, substituir o método `booking_attributes`:

```ruby
    def booking_attributes
      permitted = params.expect(booking: [ :property_id, :guest_id, :check_in, :check_out, :total_price ])
      {
        property: Current.host.properties.find(permitted[:property_id]),
        guest: Current.host.guests.find(permitted[:guest_id]),
        check_in: permitted[:check_in],
        check_out: permitted[:check_out],
        total_price: permitted[:total_price]
      }
    end
```

- [ ] **Step 4: Adicionar o campo ao formulário**

Em `app/views/bookings/_form.html.erb`, inserir entre o `<div class="grid grid-cols-2 gap-4">…</div>` (que fecha na linha do check-out) e o `<div class="flex items-center gap-3 pt-2">`:

```erb
  <div>
    <%= f.label :total_price, "Preço total da reserva", class: "block text-sm font-medium text-gray-700" %>
    <div class="relative mt-1.5">
      <span class="pointer-events-none absolute inset-y-0 left-0 flex items-center pl-3.5 text-sm text-gray-500">R$</span>
      <%= f.text_field :total_price, value: booking.total_price_cents.positive? ? booking.total_price : nil,
            inputmode: "decimal", placeholder: "1.200,00",
            class: "w-full rounded-lg border-gray-300 shadow-sm focus:border-gray-900 focus:ring-1 focus:ring-gray-900 focus:outline-none text-sm pl-10 pr-3.5 py-2.5" %>
    </div>
    <p class="mt-1 text-xs text-gray-500">Opcional. Usado para calcular receita e ocupação no painel.</p>
  </div>
```

- [ ] **Step 5: Exibir o preço na página da reserva**

Em `app/views/bookings/show.html.erb`, substituir o parágrafo das linhas 14-17:

```erb
    <p class="mt-0.5 text-sm text-gray-600">
      <%= @booking.property.name %> · <%= l @booking.check_in %> a <%= l @booking.check_out %>
      · CPF <%= @booking.guest.masked_cpf %>
      <% if @booking.total_price_cents.positive? %>
        · <%= number_to_currency(@booking.total_price_cents / 100.0, unit: "R$") %>
      <% end %>
    </p>
```

- [ ] **Step 6: Rodar os testes para ver passar**

```bash
bundle exec rspec spec/requests/bookings_spec.rb
```

Esperado: PASS em todos os exemplos.

- [ ] **Step 7: Rodar o lint e commitar**

```bash
bin/rubocop app/controllers/bookings_controller.rb
git add app/controllers/bookings_controller.rb app/views/bookings spec/requests/bookings_spec.rb
git commit -m "feat: informa preço total ao criar reserva"
```

---

### Task 6: Rota e esqueleto do dashboard

**Files:**
- Create: `app/controllers/dashboard_controller.rb`
- Create: `app/views/dashboard/show.html.erb`
- Modify: `config/routes.rb`
- Modify: `app/views/layouts/_nav.html.erb`
- Modify: `config/locales/pt-BR.yml`
- Modify: `spec/requests/authentication_spec.rb`
- Modify: `spec/requests/registrations_spec.rb`
- Test: `spec/requests/dashboard_spec.rb`

**Interfaces:**
- Consumes: `Dashboard::Metrics` (Task 4)
- Produces:
  - Rota `root "dashboard#show"` e `dashboard_path` (`/dashboard`)
  - `@metrics` (`Dashboard::Metrics`), `@tab` (String) disponíveis na view
  - `@today_checkins`, `@today_checkouts`, `@tomorrow_checkins`, `@tomorrow_checkouts` (relations de `Booking`)
  - `DashboardController::TABS` → `%w[occupancy revenue adr revpar]`

**Atenção:** `after_authentication_url` usa `root_url`. Os specs `spec/requests/authentication_spec.rb` e `spec/requests/registrations_spec.rb` fazem `get root_path` esperando 200 com um host **sem propriedades** — que agora será redirecionado para `properties_path`. Ambos precisam de ajuste nesta task.

- [ ] **Step 1: Escrever os testes que falham**

Criar `spec/requests/dashboard_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe "Painel do anfitrião", type: :request do
  let!(:host) { create(:host) }
  let!(:property) { create(:property, host: host) }
  let(:guest) { create(:guest, host: host) }

  before { sign_in host }

  it "exige login" do
    delete session_path
    get dashboard_path
    expect(response).to redirect_to(new_session_path)
  end

  it "abre o painel do anfitrião autenticado" do
    get dashboard_path
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Painel")
  end

  it "manda cadastrar hospedagem quando não há nenhuma" do
    property.destroy
    get dashboard_path
    expect(response).to redirect_to(properties_path)
  end

  it "aceita os períodos conhecidos" do
    Dashboard::Metrics::PERIODS.each do |period|
      get dashboard_path(period: period)
      expect(response).to have_http_status(:ok)
    end
  end

  it "não quebra com período ou aba desconhecidos" do
    get dashboard_path(period: "sempre", tab: "inventada")
    expect(response).to have_http_status(:ok)
  end
end
```

- [ ] **Step 2: Rodar os testes para ver falhar**

```bash
bundle exec rspec spec/requests/dashboard_spec.rb
```

Esperado: FAIL com `NameError: undefined local variable or method 'dashboard_path'`.

- [ ] **Step 3: Adicionar as rotas**

Em `config/routes.rb`, substituir a linha `root "properties#index"` por:

```ruby
  root "dashboard#show"
  get "dashboard", to: "dashboard#show", as: :dashboard
```

- [ ] **Step 4: Criar o controller**

Criar `app/controllers/dashboard_controller.rb`:

```ruby
class DashboardController < ApplicationController
  TABS = %w[occupancy revenue adr revpar].freeze

  def show
    @metrics = Dashboard::Metrics.new(Current.host, params[:period])
    @tab = TABS.include?(params[:tab]) ? params[:tab] : "occupancy"

    # Sem hospedagem não há o que medir; o lugar certo é o cadastro.
    return redirect_to properties_path if @metrics.properties_count.zero?

    load_timeline
  end

  private
    def load_timeline
      scoped = Current.host.bookings.includes(:property, :guest)
      @today_checkins = scoped.where(check_in: Date.current)
      @today_checkouts = scoped.where(check_out: Date.current)
      @tomorrow_checkins = scoped.where(check_in: Date.current + 1)
      @tomorrow_checkouts = scoped.where(check_out: Date.current + 1)
    end
end
```

- [ ] **Step 5: Criar a view mínima**

Criar `app/views/dashboard/show.html.erb`:

```erb
<div class="mb-6">
  <h1 class="text-2xl font-bold tracking-tight text-gray-900">Painel</h1>
  <p class="mt-1 text-sm text-gray-600">Seus números dos últimos 30 dias e o que acontece hoje</p>
</div>
```

- [ ] **Step 6: Adicionar o link na navegação**

Em `config/locales/pt-BR.yml`, dentro do bloco `nav:` (linha 10), adicionar como **primeira** entrada, antes de `properties:`:

```yaml
    dashboard: "Painel"
```

Em `app/views/layouts/_nav.html.erb`, adicionar como primeiro `<li>` da lista mobile (antes do `nav-properties-mobile`):

```erb
          <li><%= nav_link_mobile t("nav.dashboard"), dashboard_path, "nav-dashboard-mobile" %></li>
```

E como primeiro link do bloco desktop (antes do `nav-properties`):

```erb
        <%= nav_link t("nav.dashboard"), dashboard_path, "nav-dashboard" %>
```

Trocar também o `href` do logo (linha 34) de `properties_path` para `dashboard_path`.

- [ ] **Step 7: Ajustar os specs de autenticação e cadastro**

Em `spec/requests/authentication_spec.rb`, no exemplo `"dá acesso após o login e encerra no logout"`, o host não tem propriedade e agora cai no redirect. Trocar o corpo do exemplo por:

```ruby
  it "dá acesso após o login e encerra no logout" do
    create(:property, host: host)
    sign_in host
    get root_path
    expect(response).to have_http_status(:ok)

    delete session_path
    expect(response).to redirect_to(new_session_path)
    expect(host.sessions.count).to eq(0)
  end
```

Em `spec/requests/registrations_spec.rb`, no exemplo `"cria conta, inicia trial e loga"`, o anfitrião recém-criado nunca tem propriedade. Trocar as duas últimas linhas do exemplo:

```ruby
    expect(response).to redirect_to(root_path)

    get root_path
    expect(response).to redirect_to(properties_path)
```

- [ ] **Step 8: Rodar a suíte inteira para ver passar**

```bash
bundle exec rspec
```

Esperado: PASS. Se algum outro spec quebrar por causa do `root_path`, ajustar a expectativa da mesma forma.

- [ ] **Step 9: Rodar o lint e commitar**

```bash
bin/rubocop app/controllers/dashboard_controller.rb spec/requests
git add app/controllers/dashboard_controller.rb app/views/dashboard config/routes.rb app/views/layouts/_nav.html.erb config/locales/pt-BR.yml spec/requests
git commit -m "feat: cria rota e esqueleto do painel do anfitrião"
```

---

### Task 7: Cards de KPI

**Files:**
- Create: `app/helpers/dashboard_helper.rb`
- Create: `app/views/dashboard/_kpi_cards.html.erb`
- Modify: `app/views/dashboard/show.html.erb`
- Test: `spec/requests/dashboard_spec.rb`

**Interfaces:**
- Consumes: `@metrics.kpis`, `@metrics.revenue_change_percentage` (Tasks 4 e 6)
- Produces:
  - `DashboardHelper#money_from_cents(cents)` → String (ex: `"R$ 300,00"`)
  - `DashboardHelper#money(reais)` → String
  - `DashboardHelper#percentage(value)` → String (ex: `"52,4%"`)
  - `DashboardHelper#occupancy_badge_class(rate)` → String de classes Tailwind
  - Partial `dashboard/_kpi_cards` (sem locals, usa `@metrics`)

- [ ] **Step 1: Escrever os testes que falham**

Adicionar em `spec/requests/dashboard_spec.rb`, antes do `end` final:

```ruby
  it "mostra os quatro indicadores" do
    create(:booking, property: property, guest: guest,
           check_in: Date.current, check_out: Date.current + 2, total_price_cents: 30_000)

    get dashboard_path

    expect(response.body).to include("Ocupação")
    expect(response.body).to include("Receita")
    expect(response.body).to include("Diária média")
    expect(response.body).to include("RevPAR")
    expect(response.body).to include("300,00")
  end

  it "zera os indicadores sem reservas" do
    get dashboard_path

    expect(response.body).to include("0,0%")
    expect(response.body).to include("R$ 0,00")
  end
```

- [ ] **Step 2: Rodar os testes para ver falhar**

```bash
bundle exec rspec spec/requests/dashboard_spec.rb -e "mostra os quatro indicadores"
```

Esperado: FAIL — o body não contém "Ocupação".

- [ ] **Step 3: Criar o helper**

Criar `app/helpers/dashboard_helper.rb`:

```ruby
module DashboardHelper
  def money_from_cents(cents)
    money(cents / 100.0)
  end

  def money(reais)
    number_to_currency(reais, unit: "R$", separator: ",", delimiter: ".")
  end

  def percentage(value)
    number_to_percentage(value, precision: 1, separator: ",")
  end

  # Verde acima de 70%, âmbar entre 40% e 70%, vermelho abaixo disso.
  def occupancy_badge_class(rate)
    case rate
    when 70.. then "bg-green-100 text-green-800"
    when 40...70 then "bg-amber-100 text-amber-800"
    else "bg-red-100 text-red-800"
    end
  end

  def revenue_change_label(percentage)
    return "Sem base de comparação" if percentage.nil?

    signal = percentage.positive? ? "+" : ""
    "#{signal}#{number_with_precision(percentage, precision: 1, separator: ',')}% vs. período anterior"
  end

  def revenue_change_class(percentage)
    return "text-gray-500" if percentage.nil? || percentage.zero?

    percentage.positive? ? "text-green-700" : "text-red-700"
  end
end
```

- [ ] **Step 4: Criar a partial dos cards**

Criar `app/views/dashboard/_kpi_cards.html.erb`:

```erb
<% kpis = @metrics.kpis %>
<div class="grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
  <div class="rounded-lg border border-gray-200 bg-white p-4">
    <p class="text-xs font-medium uppercase tracking-wide text-gray-500">Ocupação</p>
    <p class="mt-2 text-2xl font-bold tracking-tight text-gray-900"><%= percentage(kpis[:occupancy]) %></p>
    <span class="mt-2 inline-block rounded-full px-2.5 py-0.5 text-xs font-medium <%= occupancy_badge_class(kpis[:occupancy]) %>">
      das noites disponíveis
    </span>
  </div>

  <div class="rounded-lg border border-gray-200 bg-white p-4">
    <p class="text-xs font-medium uppercase tracking-wide text-gray-500">Receita</p>
    <p class="mt-2 text-2xl font-bold tracking-tight text-gray-900"><%= money_from_cents(kpis[:revenue]) %></p>
    <p class="mt-2 text-xs font-medium <%= revenue_change_class(@metrics.revenue_change_percentage) %>">
      <%= revenue_change_label(@metrics.revenue_change_percentage) %>
    </p>
  </div>

  <div class="rounded-lg border border-gray-200 bg-white p-4">
    <p class="text-xs font-medium uppercase tracking-wide text-gray-500">Diária média</p>
    <p class="mt-2 text-2xl font-bold tracking-tight text-gray-900"><%= money(kpis[:adr]) %></p>
    <p class="mt-2 text-xs text-gray-500">por noite vendida</p>
  </div>

  <div class="rounded-lg border border-gray-200 bg-white p-4">
    <p class="text-xs font-medium uppercase tracking-wide text-gray-500">RevPAR</p>
    <p class="mt-2 text-2xl font-bold tracking-tight text-gray-900"><%= money(kpis[:revpar]) %></p>
    <p class="mt-2 text-xs text-gray-500">por noite disponível</p>
  </div>
</div>
```

- [ ] **Step 5: Renderizar na view**

Em `app/views/dashboard/show.html.erb`, adicionar após o bloco do título:

```erb
<%= render "dashboard/kpi_cards" %>
```

- [ ] **Step 6: Rodar os testes para ver passar**

```bash
bundle exec rspec spec/requests/dashboard_spec.rb
```

Esperado: PASS em todos os exemplos.

- [ ] **Step 7: Rodar o lint e commitar**

```bash
bin/rubocop app/helpers/dashboard_helper.rb
git add app/helpers/dashboard_helper.rb app/views/dashboard spec/requests/dashboard_spec.rb
git commit -m "feat: exibe indicadores de ocupação e receita no painel"
```

---

### Task 8: Timeline de hoje e amanhã

**Files:**
- Create: `app/views/dashboard/_timeline.html.erb`
- Create: `app/views/dashboard/_day.html.erb`
- Modify: `app/views/dashboard/show.html.erb`
- Test: `spec/requests/dashboard_spec.rb`

**Interfaces:**
- Consumes: `@today_checkins`, `@today_checkouts`, `@tomorrow_checkins`, `@tomorrow_checkouts` (Task 6); `guide_link_for` de `BookingsHelper`
- Produces: partial `dashboard/_day` com locals `title:`, `date:`, `checkins:`, `checkouts:`

- [ ] **Step 1: Escrever os testes que falham**

Adicionar em `spec/requests/dashboard_spec.rb`, antes do `end` final:

```ruby
  it "lista o check-in de hoje com o nome do hóspede" do
    create(:booking, property: property, guest: guest,
           check_in: Date.current, check_out: Date.current + 2)

    get dashboard_path

    expect(response.body).to include("Hoje")
    expect(response.body).to include(guest.name)
  end

  it "lista o check-out de amanhã" do
    create(:booking, property: property, guest: guest,
           check_in: Date.current - 2, check_out: Date.current + 1)

    get dashboard_path

    expect(response.body).to include("Amanhã")
    expect(response.body).to include(guest.name)
  end

  it "avisa quando não há movimento no dia" do
    get dashboard_path

    expect(response.body).to include("Nenhuma chegada ou saída")
  end
```

- [ ] **Step 2: Rodar os testes para ver falhar**

```bash
bundle exec rspec spec/requests/dashboard_spec.rb -e "lista o check-in de hoje"
```

Esperado: FAIL — o body não contém "Hoje".

- [ ] **Step 3: Criar a partial de um dia**

Criar `app/views/dashboard/_day.html.erb`:

```erb
<section class="rounded-lg border border-gray-200 bg-white p-4">
  <header class="flex items-baseline justify-between border-b border-gray-100 pb-3">
    <h3 class="text-sm font-semibold text-gray-900"><%= title %></h3>
    <span class="text-xs text-gray-500"><%= l date, format: :long %></span>
  </header>

  <% if checkins.none? && checkouts.none? %>
    <p class="pt-4 text-sm text-gray-500">Nenhuma chegada ou saída prevista.</p>
  <% else %>
    <div class="space-y-4 pt-4">
      <% if checkins.any? %>
        <div>
          <p class="text-xs font-medium uppercase tracking-wide text-gray-500">
            Chegadas (<%= checkins.size %>)
          </p>
          <ul class="mt-2 space-y-2">
            <% checkins.each do |booking| %>
              <li class="flex flex-wrap items-center justify-between gap-2 rounded-lg border border-gray-200 px-3 py-2.5">
                <div>
                  <p class="text-sm font-medium text-gray-900"><%= booking.guest.name %></p>
                  <p class="text-xs text-gray-500"><%= booking.property.name %></p>
                </div>
                <div class="flex gap-2">
                  <%= link_to "Ver reserva", booking_path(booking),
                        class: "rounded-lg border border-gray-300 px-3 py-1.5 text-xs font-medium text-gray-700 transition-colors hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-gray-900 focus:ring-offset-2" %>
                  <%= link_to "Ver guia", property_preview_path(booking.property),
                        class: "rounded-lg border border-gray-300 px-3 py-1.5 text-xs font-medium text-gray-700 transition-colors hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-gray-900 focus:ring-offset-2" %>
                </div>
              </li>
            <% end %>
          </ul>
        </div>
      <% end %>

      <% if checkouts.any? %>
        <div>
          <p class="text-xs font-medium uppercase tracking-wide text-gray-500">
            Saídas (<%= checkouts.size %>)
          </p>
          <ul class="mt-2 space-y-2">
            <% checkouts.each do |booking| %>
              <li class="flex flex-wrap items-center justify-between gap-2 rounded-lg border border-gray-200 px-3 py-2.5">
                <div>
                  <p class="text-sm font-medium text-gray-900"><%= booking.guest.name %></p>
                  <p class="text-xs text-gray-500"><%= booking.property.name %></p>
                </div>
                <%= link_to "Ver reserva", booking_path(booking),
                      class: "rounded-lg border border-gray-300 px-3 py-1.5 text-xs font-medium text-gray-700 transition-colors hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-gray-900 focus:ring-offset-2" %>
              </li>
            <% end %>
          </ul>
        </div>
      <% end %>
    </div>
  <% end %>
</section>
```

- [ ] **Step 4: Criar a partial da timeline**

Criar `app/views/dashboard/_timeline.html.erb`:

```erb
<div class="grid gap-4 lg:grid-cols-2">
  <%= render "dashboard/day", title: "Hoje", date: Date.current,
        checkins: @today_checkins, checkouts: @today_checkouts %>
  <%= render "dashboard/day", title: "Amanhã", date: Date.current + 1,
        checkins: @tomorrow_checkins, checkouts: @tomorrow_checkouts %>
</div>
```

- [ ] **Step 5: Renderizar na view**

Em `app/views/dashboard/show.html.erb`, envolver o conteúdo num container com espaçamento e adicionar a timeline. O arquivo fica:

```erb
<div class="mb-6">
  <h1 class="text-2xl font-bold tracking-tight text-gray-900">Painel</h1>
  <p class="mt-1 text-sm text-gray-600">Seus números dos últimos 30 dias e o que acontece hoje</p>
</div>

<div class="space-y-8">
  <%= render "dashboard/kpi_cards" %>
  <%= render "dashboard/timeline" %>
</div>
```

- [ ] **Step 6: Rodar os testes para ver passar**

```bash
bundle exec rspec spec/requests/dashboard_spec.rb
```

Esperado: PASS em todos os exemplos.

- [ ] **Step 7: Commit**

```bash
git add app/views/dashboard spec/requests/dashboard_spec.rb
git commit -m "feat: mostra chegadas e saídas de hoje e amanhã"
```

---

### Task 9: ApexCharts e o gráfico principal

**Files:**
- Create: `app/javascript/controllers/dashboard_charts_controller.js`
- Create: `app/views/dashboard/_hero_chart.html.erb`
- Modify: `app/views/dashboard/show.html.erb`
- Modify: `app/helpers/dashboard_helper.rb`
- Modify: `config/importmap.rb`
- Test: `spec/requests/dashboard_spec.rb`

**Interfaces:**
- Consumes: `@metrics.series`, `@metrics.group_unit` (Task 4); helpers da Task 7
- Produces:
  - `DashboardHelper#series_labels(series, group_unit)` → `Array<String>` (rótulos formatados do eixo X)
  - `DashboardHelper#chart_payload(metrics)` → Hash serializável para o `data-*` do Stimulus
  - Stimulus controller `dashboard-charts` com value `data` (Object)
  - ApexCharts em `vendor/javascript/apexcharts.js`

**Contexto:** a CSP do projeto é `default_src :self`, então o ApexCharts **precisa** ser baixado para `vendor/javascript`. Carregar por CDN é bloqueado pelo browser.

- [ ] **Step 1: Baixar o ApexCharts**

```bash
bin/importmap pin apexcharts --download
```

Verificar que `vendor/javascript/apexcharts.js` existe e que `config/importmap.rb` ganhou uma linha `pin "apexcharts" # @<versão>`.

- [ ] **Step 2: Escrever o teste que falha**

Adicionar em `spec/requests/dashboard_spec.rb`, antes do `end` final:

```ruby
  it "entrega os dados do gráfico para o javascript" do
    create(:booking, property: property, guest: guest,
           check_in: Date.current, check_out: Date.current + 2, total_price_cents: 30_000)

    get dashboard_path

    expect(response.body).to include("data-controller=\"dashboard-charts\"")
    expect(response.body).to include("data-dashboard-charts-data-value")
  end

  it "oferece tabela alternativa aos dados do gráfico" do
    get dashboard_path

    expect(response.body).to include("Receita e ocupação por período")
  end
```

- [ ] **Step 3: Rodar o teste para ver falhar**

```bash
bundle exec rspec spec/requests/dashboard_spec.rb -e "entrega os dados do gráfico"
```

Esperado: FAIL — o body não contém `data-controller="dashboard-charts"`.

- [ ] **Step 4: Adicionar os helpers de série**

Em `app/helpers/dashboard_helper.rb`, adicionar antes do `end` do módulo:

```ruby
  # Rótulos do eixo X, no formato que faz sentido para o agrupamento.
  def series_labels(series, group_unit)
    series.keys.map do |date|
      case group_unit
      when :day then l(date, format: "%d/%m")
      when :week then "semana de #{l(date, format: '%d/%m')}"
      else l(date, format: "%m/%Y")
      end
    end
  end

  def chart_payload(metrics)
    series = metrics.series
    {
      labels: series_labels(series[:revenue], metrics.group_unit),
      revenue: series[:revenue].values.map { |cents| (cents / 100.0).round(2) },
      occupancy: series[:occupancy].values
    }
  end
```

- [ ] **Step 5: Criar a partial do gráfico**

Criar `app/views/dashboard/_hero_chart.html.erb`:

```erb
<% payload = chart_payload(@metrics) %>
<section class="rounded-lg border border-gray-200 bg-white p-4"
         data-controller="dashboard-charts"
         data-dashboard-charts-data-value="<%= payload.to_json %>">
  <h2 class="text-sm font-semibold text-gray-900">Receita e ocupação por período</h2>

  <div class="mt-4" data-dashboard-charts-target="canvas"
       role="img" aria-label="Gráfico de receita e ocupação ao longo do período selecionado"></div>

  <table class="mt-4 hidden w-full text-sm" data-dashboard-charts-target="fallback">
    <caption class="pb-2 text-left text-xs text-gray-500">Receita e ocupação por período</caption>
    <thead>
      <tr class="border-b border-gray-200 text-left text-xs uppercase tracking-wide text-gray-500">
        <th scope="col" class="py-2">Período</th>
        <th scope="col" class="py-2">Receita</th>
        <th scope="col" class="py-2">Ocupação</th>
      </tr>
    </thead>
    <tbody>
      <% payload[:labels].each_with_index do |label, index| %>
        <tr class="border-b border-gray-100">
          <th scope="row" class="py-2 font-normal text-gray-700"><%= label %></th>
          <td class="py-2 text-gray-900"><%= money(payload[:revenue][index]) %></td>
          <td class="py-2 text-gray-900"><%= percentage(payload[:occupancy][index]) %></td>
        </tr>
      <% end %>
    </tbody>
  </table>
</section>
```

- [ ] **Step 6: Criar o Stimulus controller**

Criar `app/javascript/controllers/dashboard_charts_controller.js`:

```javascript
import { Controller } from "@hotwired/stimulus"
import ApexCharts from "apexcharts"

export default class extends Controller {
  static targets = ["canvas", "fallback"]
  static values = { data: Object }

  connect() {
    try {
      this.chart = new ApexCharts(this.canvasTarget, this.options())
      this.chart.render()
    } catch {
      // Sem o gráfico, o anfitrião ainda precisa enxergar os números.
      this.showFallback()
    }
  }

  disconnect() {
    this.chart?.destroy()
    this.chart = null
  }

  options() {
    const { labels, revenue, occupancy } = this.dataValue

    return {
      chart: { type: "line", height: 280, toolbar: { show: false }, fontFamily: "inherit" },
      colors: ["#111827", "#9ca3af"],
      stroke: { width: 2, curve: "smooth" },
      series: [
        { name: "Receita", type: "line", data: revenue },
        { name: "Ocupação", type: "line", data: occupancy }
      ],
      xaxis: { categories: labels, labels: { rotate: -45, style: { fontSize: "11px" } } },
      yaxis: [
        { title: { text: "Receita (R$)" }, labels: { formatter: (value) => this.currency(value) } },
        { opposite: true, title: { text: "Ocupação (%)" }, max: 100, labels: { formatter: (value) => `${value}%` } }
      ],
      tooltip: {
        shared: true,
        y: [
          { formatter: (value) => this.currency(value) },
          { formatter: (value) => `${value}%` }
        ]
      },
      legend: { position: "top", horizontalAlign: "right" },
      grid: { borderColor: "#e5e7eb" },
      noData: { text: "Sem dados para este período" }
    }
  }

  currency(value) {
    return new Intl.NumberFormat("pt-BR", { style: "currency", currency: "BRL" }).format(value ?? 0)
  }

  showFallback() {
    this.canvasTarget.classList.add("hidden")
    this.fallbackTarget.classList.remove("hidden")
  }
}
```

- [ ] **Step 7: Renderizar na view**

Em `app/views/dashboard/show.html.erb`, adicionar o gráfico entre os cards e a timeline:

```erb
<div class="space-y-8">
  <%= render "dashboard/kpi_cards" %>
  <%= render "dashboard/hero_chart" %>
  <%= render "dashboard/timeline" %>
</div>
```

- [ ] **Step 8: Rodar os testes para ver passar**

```bash
bundle exec rspec spec/requests/dashboard_spec.rb
```

Esperado: PASS em todos os exemplos.

- [ ] **Step 9: Conferir no browser**

```bash
bin/dev
```

Abrir `http://localhost:3000`, logar e confirmar: o gráfico renderiza, a tabela alternativa fica escondida, e não há erro de CSP no console do browser.

- [ ] **Step 10: Rodar o lint e commitar**

```bash
bin/rubocop app/helpers/dashboard_helper.rb
git add app/javascript/controllers/dashboard_charts_controller.js app/views/dashboard app/helpers/dashboard_helper.rb config/importmap.rb vendor/javascript spec/requests/dashboard_spec.rb
git commit -m "feat: desenha gráfico de receita e ocupação no painel"
```

---

### Task 10: Tabs de performance com Turbo Frame

**Files:**
- Create: `app/views/dashboard/_performance.html.erb`
- Modify: `app/views/dashboard/show.html.erb`
- Modify: `app/javascript/controllers/dashboard_charts_controller.js`
- Modify: `app/helpers/dashboard_helper.rb`
- Test: `spec/requests/dashboard_spec.rb`

**Interfaces:**
- Consumes: `@tab`, `DashboardController::TABS` (Task 6); `@metrics` (Task 4); Stimulus `dashboard-charts` (Task 9)
- Produces:
  - `DashboardHelper#period_options` → `Array<[String, String]>` pares `[valor, rótulo]`
  - `DashboardHelper#tab_options` → `Array<[String, String]>` pares `[valor, rótulo]`
  - `DashboardHelper#tab_series_payload(metrics, tab)` → Hash para o gráfico de barras
  - Turbo Frame `#performance`

**Contexto:** o Turbo casa o frame pelo id na resposta HTML completa. Nenhum tratamento especial no controller — os links só precisam apontar para `dashboard_path(period:, tab:)` e estar dentro do frame.

- [ ] **Step 1: Escrever os testes que falham**

Adicionar em `spec/requests/dashboard_spec.rb`, antes do `end` final:

```ruby
  it "marca a aba escolhida" do
    get dashboard_path(tab: "revenue")

    expect(response.body).to include("aria-selected=\"true\"")
    expect(response.body).to match(/aria-selected="true"[^>]*>\s*Receita/m)
  end

  it "não marca a aba não escolhida" do
    get dashboard_path(tab: "revenue")

    expect(response.body).to match(/aria-selected="false"[^>]*>\s*Ocupação/m)
  end

  it "responde ao recarregamento do quadro de desempenho" do
    get dashboard_path(period: "90d", tab: "adr"), headers: { "Turbo-Frame" => "performance" }

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("performance")
  end

  it "oferece todos os períodos" do
    get dashboard_path

    expect(response.body).to include("7 dias")
    expect(response.body).to include("90 dias")
    expect(response.body).to include("12 meses")
    expect(response.body).to include("Ano")
  end
```

- [ ] **Step 2: Rodar os testes para ver falhar**

```bash
bundle exec rspec spec/requests/dashboard_spec.rb -e "marca a aba escolhida"
```

Esperado: FAIL — o body não contém `aria-selected="true"`.

- [ ] **Step 3: Adicionar os helpers das tabs**

Em `app/helpers/dashboard_helper.rb`, adicionar antes do `end` do módulo:

```ruby
  def period_options
    [
      [ "7d", "7 dias" ],
      [ "30d", "30 dias" ],
      [ "90d", "90 dias" ],
      [ "12m", "12 meses" ],
      [ "year", "Ano" ]
    ]
  end

  def tab_options
    [
      [ "occupancy", "Ocupação" ],
      [ "revenue", "Receita" ],
      [ "adr", "Diária média" ],
      [ "revpar", "RevPAR" ]
    ]
  end

  # ADR e RevPAR são médias do período inteiro, não séries. Repetimos o valor
  # em cada balde para o gráfico mostrar a linha de referência.
  def tab_series_payload(metrics, tab)
    series = metrics.series
    labels = series_labels(series[:revenue], metrics.group_unit)

    values = case tab
    when "occupancy" then series[:occupancy].values
    when "revenue" then series[:revenue].values.map { |cents| (cents / 100.0).round(2) }
    when "adr" then labels.map { metrics.kpis[:adr] }
    else labels.map { metrics.kpis[:revpar] }
    end

    { labels: labels, values: values, format: tab == "occupancy" ? "percent" : "currency" }
  end
```

- [ ] **Step 4: Criar a partial de performance**

Criar `app/views/dashboard/_performance.html.erb`:

```erb
<%= turbo_frame_tag "performance", class: "block rounded-lg border border-gray-200 bg-white p-4" do %>
  <% payload = tab_series_payload(@metrics, @tab) %>

  <div class="flex flex-wrap items-center justify-between gap-3">
    <div class="flex flex-wrap gap-1" role="tablist" aria-label="Indicador exibido no gráfico">
      <% tab_options.each do |value, label| %>
        <% selected = @tab == value %>
        <%= link_to label, dashboard_path(period: @metrics.period, tab: value),
              role: "tab", "aria-selected": selected.to_s,
              class: "rounded-lg px-3 py-1.5 text-sm font-medium transition-colors focus:outline-none focus:ring-2 focus:ring-gray-900 focus:ring-offset-2 #{selected ? 'bg-gray-900 text-white' : 'text-gray-600 hover:bg-gray-50 hover:text-gray-900'}" %>
      <% end %>
    </div>

    <div class="flex flex-wrap gap-1" role="group" aria-label="Período analisado">
      <% period_options.each do |value, label| %>
        <% selected = @metrics.period == value %>
        <%= link_to label, dashboard_path(period: value, tab: @tab),
              "aria-current": selected ? "true" : nil,
              class: "rounded-lg border px-3 py-1.5 text-xs font-medium transition-colors focus:outline-none focus:ring-2 focus:ring-gray-900 focus:ring-offset-2 #{selected ? 'border-gray-900 bg-gray-900 text-white' : 'border-gray-300 text-gray-600 hover:bg-gray-50 hover:text-gray-900'}" %>
      <% end %>
    </div>
  </div>

  <div class="mt-4"
       data-controller="dashboard-charts"
       data-dashboard-charts-data-value="<%= payload.to_json %>"
       data-dashboard-charts-kind-value="bar">
    <div data-dashboard-charts-target="canvas"
         role="img" aria-label="Gráfico de barras do indicador selecionado"></div>

    <table class="mt-4 hidden w-full text-sm" data-dashboard-charts-target="fallback">
      <caption class="pb-2 text-left text-xs text-gray-500">Valores por período</caption>
      <thead>
        <tr class="border-b border-gray-200 text-left text-xs uppercase tracking-wide text-gray-500">
          <th scope="col" class="py-2">Período</th>
          <th scope="col" class="py-2">Valor</th>
        </tr>
      </thead>
      <tbody>
        <% payload[:labels].each_with_index do |label, index| %>
          <tr class="border-b border-gray-100">
            <th scope="row" class="py-2 font-normal text-gray-700"><%= label %></th>
            <td class="py-2 text-gray-900">
              <%= payload[:format] == "percent" ? percentage(payload[:values][index]) : money(payload[:values][index]) %>
            </td>
          </tr>
        <% end %>
      </tbody>
    </table>
  </div>
<% end %>
```

- [ ] **Step 5: Ensinar o Stimulus controller a desenhar barras**

Em `app/javascript/controllers/dashboard_charts_controller.js`, substituir a linha `static values = { data: Object }` por:

```javascript
  static values = { data: Object, kind: { type: String, default: "hero" } }
```

E substituir o método `options()` por dois métodos:

```javascript
  options() {
    return this.kindValue === "bar" ? this.barOptions() : this.heroOptions()
  }

  heroOptions() {
    const { labels, revenue, occupancy } = this.dataValue

    return {
      chart: { type: "line", height: 280, toolbar: { show: false }, fontFamily: "inherit" },
      colors: ["#111827", "#9ca3af"],
      stroke: { width: 2, curve: "smooth" },
      series: [
        { name: "Receita", type: "line", data: revenue },
        { name: "Ocupação", type: "line", data: occupancy }
      ],
      xaxis: { categories: labels, labels: { rotate: -45, style: { fontSize: "11px" } } },
      yaxis: [
        { title: { text: "Receita (R$)" }, labels: { formatter: (value) => this.currency(value) } },
        { opposite: true, title: { text: "Ocupação (%)" }, max: 100, labels: { formatter: (value) => `${value}%` } }
      ],
      tooltip: {
        shared: true,
        y: [
          { formatter: (value) => this.currency(value) },
          { formatter: (value) => `${value}%` }
        ]
      },
      legend: { position: "top", horizontalAlign: "right" },
      grid: { borderColor: "#e5e7eb" },
      noData: { text: "Sem dados para este período" }
    }
  }

  barOptions() {
    const { labels, values, format } = this.dataValue
    const formatter = format === "percent"
      ? (value) => `${value}%`
      : (value) => this.currency(value)

    return {
      chart: { type: "bar", height: 280, toolbar: { show: false }, fontFamily: "inherit" },
      colors: ["#111827"],
      plotOptions: { bar: { borderRadius: 3, columnWidth: "60%" } },
      dataLabels: { enabled: false },
      series: [{ name: "Valor", data: values }],
      xaxis: { categories: labels, labels: { rotate: -45, style: { fontSize: "11px" } } },
      yaxis: { labels: { formatter } },
      tooltip: { y: { formatter } },
      grid: { borderColor: "#e5e7eb" },
      noData: { text: "Sem dados para este período" }
    }
  }
```

- [ ] **Step 6: Renderizar na view**

Em `app/views/dashboard/show.html.erb`, adicionar a performance após o gráfico principal:

```erb
<div class="space-y-8">
  <%= render "dashboard/kpi_cards" %>
  <%= render "dashboard/hero_chart" %>
  <%= render "dashboard/performance" %>
  <%= render "dashboard/timeline" %>
</div>
```

- [ ] **Step 7: Rodar os testes para ver passar**

```bash
bundle exec rspec spec/requests/dashboard_spec.rb
```

Esperado: PASS em todos os exemplos.

- [ ] **Step 8: Conferir no browser**

```bash
bin/dev
```

Abrir `http://localhost:3000`, logar e confirmar: trocar de aba e de período recarrega só o quadro de desempenho (o gráfico principal e a timeline ficam parados), o gráfico de barras redesenha a cada troca, e não há erro no console.

- [ ] **Step 9: Rodar o lint e commitar**

```bash
bin/rubocop app/helpers/dashboard_helper.rb
git add app/views/dashboard app/javascript/controllers/dashboard_charts_controller.js app/helpers/dashboard_helper.rb spec/requests/dashboard_spec.rb
git commit -m "feat: alterna indicadores e períodos no quadro de desempenho"
```

---

### Task 11: Fechamento

**Files:**
- Modify: `app/views/dashboard/show.html.erb`
- Test: suíte completa

**Interfaces:**
- Consumes: tudo das tasks anteriores
- Produces: subtítulo do painel coerente com o período escolhido; suíte verde

- [ ] **Step 1: Ajustar o subtítulo ao período**

O subtítulo hoje diz "últimos 30 dias" mesmo quando o anfitrião escolhe outro período. Em `app/views/dashboard/show.html.erb`, trocar o parágrafo do cabeçalho por:

```erb
  <p class="mt-1 text-sm text-gray-600">
    Seus números do período selecionado e o que acontece hoje
  </p>
```

- [ ] **Step 2: Rodar a suíte inteira**

```bash
bundle exec rspec
```

Esperado: PASS em todos os arquivos, sem exemplos pendentes.

- [ ] **Step 3: Rodar o lint no projeto inteiro**

```bash
bin/rubocop
```

Esperado: `no offenses detected`.

- [ ] **Step 4: Rodar a análise de segurança**

```bash
bin/brakeman --no-pager
```

Esperado: `No warnings found` — o baseline do projeto é zero avisos. Qualquer aviso novo precisa ser corrigido antes do commit.

- [ ] **Step 4b: Conferir o autoload**

```bash
bin/rails zeitwerk:check
```

Esperado: `All is good!`.

- [ ] **Step 5: Commit**

```bash
git add app/views/dashboard/show.html.erb
git commit -m "feat: ajusta cabeçalho do painel ao período escolhido"
```
