# Subprojeto 5 — Dashboard do Anfitrião (Host)

**Data:** 2026-08-11
**Status:** Aprovado
**Escopo:** Implementação do dashboard executivo do Anfitrião (Host) com KPIs financeiros, gráficos interativos e timeline operacional.

---

## 1. Visão Geral

O dashboard do Anfitrião substitui a listagem de propriedades (`properties#index`) como página inicial autenticada. Ele oferece uma visão "executiva" mista:

- **Hero**: 4 KPI cards financeiros (Ocupação, Receita, ADR, RevPAR) + gráfico de linha dual-axis
- **Timeline operacional**: Check-ins e check-outs de Hoje e Amanhã
- **Performance**: Tabs com gráficos detalhados por métrica + seletor de período (7d, 30d, 90d, 12m, ano)

O anfitrião típico acessa semanalmente para gestão, portanto o dashboard entrega tudo em uma única tela sem necessidade de navegação adicional.

---

## 2. Modelo de Dados: Preço da Reserva

### 2.1 Migration

Adicionar coluna `total_price_cents` à tabela `bookings`:

```ruby
class AddTotalPriceCentsToBookings < ActiveRecord::Migration[8.1]
  def change
    add_column :bookings, :total_price_cents, :integer, null: false, default: 0
  end
end
```

- **Tipo**: integer (centavos), não nulo, default 0
- **Default 0**: permite reservas sem preço informado; KPIs de receita ignoram reservas com valor 0, mas KPIs de ocupação as contam normalmente

### 2.2 Model `Booking`

Reader e writer que traduzem entre reais (formulário) e centavos (banco). Sem callback, sem `attribute` virtual:

```ruby
# app/models/booking.rb
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

**Sem `money-rails`**: conversão DIY para evitar gem adicional. Exibição via `number_to_currency` nativo.

### 2.3 Query Methods (KPIs)

Duas formas de recortar reservas por período, com propósitos diferentes:

- **`within_range`** (por `check_in`) — usado para **receita**: o valor da reserva é atribuído à data de check-in
- **`overlapping`** — usado para **ocupação**: uma reserva que atravessa a borda do período conta apenas as noites dentro dele

```ruby
# app/models/booking.rb
scope :active, -> { where(revoked_at: nil) }
scope :within_range, ->(start_date, end_date) { where(check_in: start_date..end_date) }
scope :overlapping, ->(start_date, end_date) {
  where(check_in: ..end_date).where(check_out: start_date..)
}

# Noites ocupadas dentro do período, recortadas nas bordas.
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

# Average Daily Rate: receita por noite efetivamente vendida.
def self.adr(start_date, end_date)
  priced = active.within_range(start_date, end_date).where("total_price_cents > 0")
  sold_nights = priced.sum(&:nights)
  return 0.0 if sold_nights.zero?

  (priced.sum(:total_price_cents).to_f / sold_nights / 100).round(2)
end

# Revenue Per Available Room: receita por noite disponível.
def self.revpar(start_date, end_date, properties_count)
  capacity = available_nights(start_date, end_date, properties_count)
  return 0.0 if capacity.zero?

  (revenue_in_range(start_date, end_date).to_f / 100 / capacity).round(2)
end
```

### 2.4 Formulário de Reserva

`BookingsController#new` e `#create` recebem `total_price` como campo de formulário. O callback `set_total_price_cents` converte para centavos antes de salvar.

Campo no formulário: input text com label "Preço total da reserva (R$)", placeholder "Ex: 1.200,00", opcional.

### 2.5 Agregações por período

Séries temporais calculadas em Ruby, sem dependência da gem `groupdate`. A ocupação precisa distribuir noites por dia (uma reserva ocupa vários dias), o que `GROUP BY` não resolve sozinho — e a mesma estrutura de buckets serve para receita.

```ruby
# app/models/booking.rb
def self.bucket_key(date, group_unit)
  case group_unit
  when :day then date
  when :week then date.beginning_of_week
  else date.beginning_of_month
  end
end

def self.revenue_series(start_date, end_date, group_unit)
  buckets = {}
  (start_date..end_date).each { |date| buckets[bucket_key(date, group_unit)] ||= 0 }

  active.within_range(start_date..end_date).each do |booking|
    buckets[bucket_key(booking.check_in, group_unit)] += booking.total_price_cents
  end

  buckets
end

def self.occupancy_series(start_date, end_date, group_unit, properties_count)
  nights_per_day = Hash.new(0)
  active.within_range(start_date..end_date).each do |booking|
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

`group_unit` determinado pelo seletor de período:
- 7d, 30d → `:day`
- 90d → `:week`
- 12m, ano → `:month`

---

## 3. Arquitetura & Rotas

### 3.1 Controller

Novo `DashboardController` herda de `ApplicationController`:

O cálculo das métricas vive em `Dashboard::Metrics`, um PORO em `app/models/dashboard/metrics.rb`. O controller só resolve período, delega e monta a timeline.

```ruby
# app/models/dashboard/metrics.rb
class Dashboard::Metrics
  PERIODS = %w[7d 30d 90d 12m year].freeze
  DEFAULT_PERIOD = "30d".freeze

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

  # Receita do período imediatamente anterior, de mesmo tamanho, para a variação %.
  def previous_revenue
    span = (ends_on - starts_on).to_i + 1
    bookings.revenue_in_range(starts_on - span, starts_on - 1)
  end

  def revenue_change_percentage
    return nil if previous_revenue.zero?

    ((kpis[:revenue] - previous_revenue).to_f / previous_revenue * 100).round(1)
  end

  private

  def bookings = @host.bookings
  def starts_on = date_range.begin
  def ends_on = date_range.end

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
```

```ruby
# app/controllers/dashboard_controller.rb
class DashboardController < ApplicationController
  TABS = %w[occupancy revenue adr revpar].freeze

  def show
    @metrics = Dashboard::Metrics.new(Current.host, params[:period])
    @tab = TABS.include?(params[:tab]) ? params[:tab] : "occupancy"

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

O seletor de período e as tabs de performance vivem dentro de um `turbo_frame_tag "performance"`. Quando o usuário troca período ou tab, o Turbo faz uma nova requisição para `dashboard_path(period:, tab:)` e substitui apenas o conteúdo do frame — sem `respond_to` especial no controller, já que o Turbo casa o frame pelo id na resposta HTML completa.

### 3.2 Rotas

```ruby
# config/routes.rb
root "dashboard#show"
get "dashboard", to: "dashboard#show", as: :dashboard
# Properties#index deixa de ser root, continua acessível em /properties
```

`root_path` continua sendo o destino pós-login (`after_authentication_url` usa `root_url`), então os specs de autenticação e cadastro que fazem `get root_path` seguem passando — desde que o host tenha propriedade cadastrada ou o redirect para `properties_path` seja esperado.

### 3.3 Dependências

Apenas **ApexCharts** (JS), via importmap com download local para `vendor/javascript` (padrão já usado pelo `sortablejs`, e exigido pela CSP `default_src :self`):

```bash
bin/importmap pin apexcharts --download
```

```ruby
# config/importmap.rb
pin "apexcharts" # @3.54.1
```

Nenhuma gem nova. As séries temporais são calculadas em Ruby (seção 2.5).

---

## 4. Componentes da View

### 4.1 Estrutura

```
app/views/dashboard/
  show.html.erb           # página completa
  _kpi_cards.html.erb     # 4 cards KPI do hero
  _hero_chart.html.erb    # gráfico dual-axis (linha receita + linha ocupação)
  _timeline.html.erb      # Hoje + Amanhã (check-ins/outs)
  _performance.html.erb   # turbo frame: tabs + seletor de período + gráfico
```

### 4.2 Hero KPI Cards

4 cards em grid (1 coluna mobile, 2 tablet, 4 desktop):

| Card | Valor | Badge |
|------|-------|-------|
| Ocupação | `occupancy_rate` % | verde >70%, amarelo 40-70%, vermelho <40% |
| Receita | `revenue` em R$ | variação % vs período anterior (mesmo tamanho) |
| ADR | `adr` em R$ | sem badge |
| RevPAR | `revpar` em R$ | sem badge |

Cada card: título + valor grande (text-2xl) + badge/subtítulo.

### 4.3 Hero Chart

Gráfico de linha dual-axis (ApexCharts):
- **Linha 1**: Receita por período (eixo Y esquerdo, R$)
- **Linha 2**: Ocupação por período (eixo Y direito, %)

Dados passados via `data-chart-data` JSON no elemento DOM, lidos pelo Stimulus controller.

### 4.4 Timeline Operacional

Dois blocos lado a lado (stack no mobile):

**Hoje**:
- Data formatada (ex: "Ter 12 Ago")
- Seção Check-ins ↑: reservas com `check_in == Date.current`
  - Cada item: nome do hóspede + nome da hospedagem + botões [Copiar link] [Ver guia]
- Seção Check-outs ↓: reservas com `check_out == Date.current`
  - Cada item: nome do hóspede + nome da hospedagem + botão [Ver reserva]

**Amanhã**: mesma estrutura, `Date.current + 1`

Empty states: "Nenhum check-in previsto para hoje." (estilo dashed border, como já usado no projeto).

### 4.5 Performance Tabs

4 tabs: `[Ocupação] [Receita] [ADR] [RevPAR]`

Cada tab mostra um gráfico de barras (ApexCharts) com os dados agrupados por dia/semana/mês conforme o período selecionado.

**Seletor de período**: 5 botões segmented control: `[7D] [30D] [90D] [12M] [Ano]`

Tabs e seletor vivem dentro de `turbo_frame_tag "performance"`. Trocar qualquer um deles dispara request para `dashboard_path(period:, tab:)` e o Turbo substitui o frame.

### 4.6 Layout

- `max-w-6xl` (mesma largura do Properties#index hoje)
- Espaçamento vertical entre seções: `space-y-8`
- Cards KPI: border 1px `#e5e7eb`, zero sombras (seguindo DESIGN.md)
- Cores: monocromático charcoal `#111827`, status colors (verde/vermelho/cinza)

---

## 5. Frontend (Stimulus + ApexCharts)

### 5.1 Stimulus Controller

```
app/javascript/controllers/dashboard_charts_controller.js
```

Responsabilidades:
- Ler `data-chart-data` JSON do elemento DOM (Stimulus values API)
- Instanciar ApexCharts (hero chart + performance chart) no `connect()`
- Destruir instâncias no `disconnect()` — o Turbo Frame recria o controller a cada troca de período/tab, então o ciclo connect/disconnect já cobre a atualização
- Graceful degradation: se ApexCharts não carrega, remover a classe `hidden` da tabela HTML fallback

### 5.2 Fallback sem JS

Tabela HTML `<table>` com os mesmos dados do gráfico, renderizada no servidor e escondida por padrão (`hidden`). O Stimulus controller a mantém escondida quando o gráfico renderiza com sucesso; em caso de erro no import do ApexCharts, exibe a tabela.

---

## 6. Error Handling

| Cenário | Comportamento |
|---------|---------------|
| Sem reservas no período | KPIs mostram `R$ 0,00 / 0%`, gráfico exibe "Sem dados para este período" |
| Sem propriedades cadastradas | Redirect para `properties_path` (empty state "Cadastre sua primeira hospedagem" já existente) |
| ApexCharts falha ao carregar | Tabela HTML fallback visível |
| `properties_count = 0` em occupancy/revpar | Retorna 0 (tratado nos métodos) |
| Reserva com `total_price_cents = 0` | Conta para ocupação, não conta para receita/ADR/RevPAR |
| `params[:period]` inválido | Fallback para `30d` |

---

## 7. Testes

### 7.1 Model Tests (spec/models/booking_spec.rb)

- `total_price_cents` default 0
- `total_price=` converte string formatada ("R$ 1.200,00") → cents
- `total_price` lê cents → string com 2 casas
- `nights` retorna noites da reserva
- `revenue_in_range` soma apenas reservas não revogadas com check-in no range
- `booked_nights` recorta reservas que atravessam as bordas do período
- `occupancy_rate` retorna % e trata `properties_count = 0`
- `adr` calcula receita/noites vendidas, retorna 0 sem reservas com preço
- `revpar` calcula receita/noites disponíveis, trata `properties_count = 0`
- `revenue_series` retorna todos os buckets do período, inclusive zerados
- `occupancy_series` distribui noites por dia e agrupa por dia/semana/mês

### 7.1b Metrics Tests (spec/models/dashboard/metrics_spec.rb)

- Período inválido cai para `30d`
- Cada período produz o `date_range` e `group_unit` esperados
- `revenue_change_percentage` compara com período anterior de mesmo tamanho
- `revenue_change_percentage` retorna `nil` quando período anterior é zero
- KPIs consideram apenas reservas do host

### 7.2 Request Tests (spec/requests/dashboard_spec.rb)

- GET / sem auth → redirect to login
- GET / com host autenticado e propriedade → 200, renderiza `show`
- KPIs presentes no response (receita, ocupação, ADR, RevPAR)
- Timeline mostra check-in de hoje com nome do hóspede
- Timeline mostra empty state quando não há check-in hoje
- `?period=7d` → KPIs calculados sobre últimos 7 dias
- `?period=year` → KPIs calculados sobre ano atual
- `?period=invalido` → fallback para 30d
- `?tab=revenue` → tab de receita marcada como selecionada
- `?tab=invalido` → fallback para `occupancy`
- Sem propriedades → redirect para `properties_path`
- Sem reservas → KPIs mostram zero
- Não vaza reservas de outro anfitrião nos KPIs
- Request com header `Turbo-Frame: performance` → responde 200 com o frame

### 7.3 Factories

```ruby
# spec/factories/bookings.rb (adicionar trait)
trait :priced do
  total_price_cents { 30_000 }  # R$ 300,00
end
```

### 7.4 Sem system tests

O projeto não tem infraestrutura de system test configurada (Capybara está no Gemfile mas não há `spec/system/` nem driver). Montar essa infra está fora do escopo deste subprojeto. A cobertura de request specs valida markup, dados e navegação por Turbo Frame; a renderização do ApexCharts é verificada manualmente.

---

## 8. Performance

- Eager loading: `includes(:property, :guest)` em todas as queries de timeline
- Meta: tempo de resposta < 200ms com 100 propriedades + 1000 reservas
- `revenue_in_range` agrega no banco (`SUM`). As demais métricas iteram em Ruby porque precisam recortar noites por reserva — cada uma carrega apenas as reservas do período, não a tabela inteira
- Se virar gargalo no futuro, migrar `booked_nights` para SQL com `SUM(LEAST(check_out, :ends) - GREATEST(check_in, :starts))`

---

## 9. Acessibilidade

- WCAG 2.1 AA em todos os novos componentes
- Focus-visible rings em botões e tabs
- Tabs com `role="tablist"` / `role="tab"` / `aria-selected`
- Gráficos ApexCharts: `aria-label` descritivo nos containers
- Tabela fallback: semantic HTML com `scope` nos `<th>`
- Skip links já existentes no layout

---

## 10. Arquivos a Criar/Modificar

### Novos arquivos
| Arquivo | Descrição |
|---------|-----------|
| `db/migrate/2026XXXX_add_total_price_cents_to_bookings.rb` | Migration |
| `app/models/dashboard/metrics.rb` | PORO que resolve período e monta KPIs/séries |
| `app/controllers/dashboard_controller.rb` | Controller do dashboard |
| `app/helpers/dashboard_helper.rb` | Formatação de moeda/percentual e classes de badge |
| `app/views/dashboard/show.html.erb` | View principal |
| `app/views/dashboard/_kpi_cards.html.erb` | Partial dos 4 cards KPI |
| `app/views/dashboard/_hero_chart.html.erb` | Partial do gráfico hero |
| `app/views/dashboard/_timeline.html.erb` | Partial da timeline Hoje/Amanhã |
| `app/views/dashboard/_day.html.erb` | Partial de um dia da timeline (Hoje/Amanhã) |
| `app/views/dashboard/_performance.html.erb` | Turbo frame com tabs e seletor de período |
| `app/javascript/controllers/dashboard_charts_controller.js` | Stimulus controller para ApexCharts |
| `vendor/javascript/apexcharts.js` | ApexCharts baixado via `bin/importmap` |
| `spec/models/dashboard/metrics_spec.rb` | Testes do PORO de métricas |
| `spec/requests/dashboard_spec.rb` | Request tests |

### Arquivos modificados
| Arquivo | Modificação |
|---------|-------------|
| `app/models/booking.rb` | Adicionar `total_price`, `nights`, scopes e métodos de KPI/série |
| `app/controllers/bookings_controller.rb` | Adicionar `total_price` ao `booking_attributes` |
| `app/views/bookings/_form.html.erb` | Adicionar campo de preço |
| `app/views/bookings/show.html.erb` | Exibir preço da reserva |
| `app/views/layouts/_nav.html.erb` | Adicionar link "Painel" (desktop e mobile) |
| `config/routes.rb` | `root "dashboard#show"` + rota `/dashboard` |
| `config/importmap.rb` | Pin ApexCharts |
| `config/locales/pt-BR.yml` | Labels do dashboard e do campo de preço |
| `spec/models/booking_spec.rb` | Testes de preço e KPIs |
| `spec/requests/authentication_spec.rb` | Ajustar expectativa de `get root_path` |
| `spec/requests/registrations_spec.rb` | Ajustar expectativa de `get root_path` |
| `spec/factories/bookings.rb` | Adicionar trait `:priced` |
