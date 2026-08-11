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

Atributo virtual `total_price` (string) + callback para conversão:

```ruby
# app/models/booking.rb
attribute :total_price, :string

before_save :set_total_price_cents

def total_price
  super.presence || (total_price_cents / 100.0).to_s
end

def set_total_price_cents
  return if self[:total_price].blank?
  self.total_price_cents = self[:total_price].gsub(/[^\d,\.]/, "").tr(",", ".").to_f.*(100).to_i
end
```

**Sem `money-rails`**: conversão DIY para evitar gem adicional. Exibição via `number_to_currency` nativo.

### 2.3 Query Methods (KPIs)

```ruby
# app/models/booking.rb
scope :within_range, ->(range) { where(check_in: range) }
scope :active, -> { where(revoked_at: nil) }

def self.revenue_in_range(start_date, end_date)
  active.within_range(start_date..end_date).sum(:total_price_cents)
end

def self.occupancy_rate(start_date, end_date, properties_count)
  total_available_nights = properties_count * (end_date - start_date).to_i
  return 0 if total_available_nights.zero?

  booked_nights = active.within_range(start_date..end_date).sum do |booking|
    nights = (booking.check_out - booking.check_in).to_i
    [nights, 0].max
  end

  (booked_nights.to_f / total_available_nights * 100).round(1)
end

def self.adr(start_date, end_date)  # Average Daily Rate
  bookings = active.within_range(start_date..end_date).where("total_price_cents > 0")
  nights = bookings.sum { |b| (b.check_out - b.check_in).to_i }
  return 0 if nights.zero?

  bookings.sum(:total_price_cents).to_f / nights / 100
end

def self.revpar(start_date, end_date, properties_count)  # Revenue Per Available Room
  total_available_nights = properties_count * (end_date - start_date).to_i
  return 0 if total_available_nights.zero?

  revenue = revenue_in_range(start_date, end_date).to_f / 100
  revenue / total_available_nights
end
```

### 2.4 Formulário de Reserva

`BookingsController#new` e `#create` recebem `total_price` como campo de formulário. O callback `set_total_price_cents` converte para centavos antes de salvar.

Campo no formulário: input text com label "Preço total da reserva (R$)", placeholder "Ex: 1.200,00", opcional.

### 2.5 Agregações por período (groupdate)

```ruby
# app/models/booking.rb
def self.revenue_by_period(start_date, end_date, group_unit)
  active.within_range(start_date..end_date)
    .group_by_period(group_unit, :check_in)
    .sum(:total_price_cents)
end

def self.occupancy_by_period(start_date, end_date, group_unit, properties_count)
  return {} if properties_count.zero?

  active.within_range(start_date..end_date)
    .group_by_period(group_unit, :check_in)
    .count
    .transform_values { |count| (count.to_f / properties_count * 100).round(1) }
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

```ruby
# app/controllers/dashboard_controller.rb
class DashboardController < ApplicationController
  PERIODS = %w[7d 30d 90d 12m year].freeze
  DEFAULT_PERIOD = "30d".freeze

  def show
    @period = PERIODS.include?(params[:period]) ? params[:period] : DEFAULT_PERIOD
    @date_range = calculate_date_range(@period)
    @group_unit = determine_group_unit(@period)
    @properties_count = Current.host.properties.count

    return redirect_to properties_path if @properties_count.zero?

    bookings = Current.host.bookings

    @kpi_metrics = {
      occupancy: bookings.occupancy_rate(@date_range.begin, @date_range.end, @properties_count),
      revenue: bookings.revenue_in_range(@date_range.begin, @date_range.end),
      adr: bookings.adr(@date_range.begin, @date_range.end),
      revpar: bookings.revpar(@date_range.begin, @date_range.end, @properties_count)
    }

    @chart_data = {
      revenue: bookings.revenue_by_period(@date_range.begin, @date_range.end, @group_unit),
      occupancy: bookings.occupancy_by_period(@date_range.begin, @date_range.end, @group_unit, @properties_count)
    }

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

  def calculate_date_range(period)
    case period
    when "7d" then 7.days.ago.to_date..Date.current
    when "30d" then 30.days.ago.to_date..Date.current
    when "90d" then 90.days.ago.to_date..Date.current
    when "12m" then 12.months.ago.to_date..Date.current
    when "year" then Date.current.beginning_of_year..Date.current.end_of_year
    end
  end

  def determine_group_unit(period)
    case period
    when "7d", "30d" then :day
    when "90d" then :week
    else :month
    end
  end
end
```

O seletor de período e as tabs de performance vivem dentro de um `turbo_frame_tag "performance"`. Quando o usuário troca período ou tab, o Turbo faz uma nova requisição para `dashboard_path(period:, tab:)` e substitui apenas o conteúdo do frame — sem `respond_to` especial no controller, já que o Turbo casa o frame pelo id na resposta HTML completa.

### 3.2 Rotas

```ruby
# config/routes.rb
root to: "dashboard#show"
get "dashboard", to: "dashboard#show", as: :dashboard
# Properties#index deixa de ser root, continua acessível em /properties
```

### 3.3 Gems/Dependências

- **`groupdate`** — agrupar reservas por dia/semana/mês no PostgreSQL
- **ApexCharts** (JS) — via importmap, sem gem Ruby intermediária:

```ruby
# config/importmap.rb
pin "apexcharts", to: "https://cdn.jsdelivr.net/npm/apexcharts@3.52.0/dist/apexcharts.esm.js"
```

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
- `total_price` setter converte string formatada → cents
- `total_price` getter lê cents → decimal
- `revenue_in_range` soma apenas reservas não revogadas no range
- `occupancy_rate` retorna % e trata division by zero
- `adr` calcula receita/noites, retorna 0 sem reservas com preço
- `revpar` calcula receita/noites disponíveis, trata `properties_count = 0`
- `revenue_by_period` agrupa por dia/semana/mês corretamente (groupdate)
- `occupancy_by_period` retorna hash com taxa por período

### 7.2 Request Tests (spec/requests/dashboard_spec.rb)

- GET / sem auth → redirect to login
- GET / com host autenticado → 200, renderiza `show`
- KPIs presentes no response (receita, ocupação, adr, revpar)
- Timeline Hoje/Amanhã com check-ins/outs corretos
- `?period=7d` → KPIs calculados sobre últimos 7 dias
- `?period=12m` → KPIs calculados sobre últimos 12 meses
- `?period=year` → KPIs calculados sobre ano atual
- `?period=invalido` → fallback para 30d
- Sem propriedades → redirect para `properties_path`
- Sem reservas → KPIs mostram 0 / empty state no gráfico
- Request com header `Turbo-Frame: performance` → responde 200 com o frame

### 7.3 System Tests (spec/system/dashboard_spec.rb)

- Anfitrião acessa dashboard e vê 4 KPI cards
- Anfitrião troca período e o frame de performance atualiza
- Anfitrião troca tab de performance e gráfico correspondente aparece
- Anfitrião com check-in hoje vê bloco "Hoje" com nome do hóspede
- Anfitrião sem reservas hoje vê empty state "Nenhum check-in previsto"
- Criar reserva com preço → KPI receita reflete valor

### 7.4 Factories

```ruby
# spec/factories/bookings.rb (adicionar trait)
trait :priced do
  total_price_cents { rand(50_00..500_00) }  # R$ 50 a R$ 500
end
```

---

## 8. Performance

- Eager loading: `includes(:property, :guest)` em todas as queries de timeline
- Meta: tempo de resposta < 200ms com 100 propriedades + 1000 reservas
- Groupdate + PostgreSQL: agregações no banco, não na aplicação
- `occupancy_rate` e `adr` iteram em Ruby por precisarem de diferença de datas por reserva; aceitável no volume alvo. Se virar gargalo, migrar para SQL com `SUM(check_out - check_in)`

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
| `app/controllers/dashboard_controller.rb` | Controller do dashboard |
| `app/views/dashboard/show.html.erb` | View principal |
| `app/views/dashboard/_kpi_cards.html.erb` | Partial dos 4 cards KPI |
| `app/views/dashboard/_hero_chart.html.erb` | Partial do gráfico hero |
| `app/views/dashboard/_timeline.html.erb` | Partial da timeline Hoje/Amanhã |
| `app/views/dashboard/_performance.html.erb` | Turbo frame com tabs e seletor de período |
| `app/javascript/controllers/dashboard_charts_controller.js` | Stimulus controller para ApexCharts |
| `spec/requests/dashboard_spec.rb` | Request tests |
| `spec/system/dashboard_spec.rb` | System tests |

### Arquivos modificados
| Arquivo | Modificação |
|---------|-------------|
| `app/models/booking.rb` | Adicionar `total_price`, callbacks e query methods |
| `app/controllers/bookings_controller.rb` | Adicionar `total_price` ao `booking_params` |
| `app/views/bookings/_form.html.erb` | Adicionar campo de preço |
| `app/views/bookings/show.html.erb` | Exibir preço da reserva |
| `config/routes.rb` | `root to: "dashboard#show"` + rota `/dashboard` |
| `config/importmap.rb` | Pin ApexCharts |
| `Gemfile` | Adicionar `groupdate` |
| `config/locales/pt-BR.yml` | Labels do dashboard e campo de preço |
| `spec/models/booking_spec.rb` | Testes de KPIs |
| `spec/factories/bookings.rb` | Adicionar trait `:priced` |
