---
name: Anfitriar
description: O painel de controle do anfitrião profissional
colors:
  charcoal: "#111827"
  charcoal-deep: "#030712"
  charcoal-mid: "#374151"
  slate-text: "#6b7280"
  slate-muted: "#9ca3af"
  surface-white: "#ffffff"
  surface-base: "#f9fafb"
  border-subtle: "#e5e7eb"
  border-input: "#d1d5db"
  status-green: "#166534"
  status-green-bg: "#f0fdf4"
  status-green-border: "#bbf7d0"
  status-red: "#991b1b"
  status-red-bg: "#fef2f2"
  status-red-border: "#fecaca"
  status-gray-bg: "#f3f4f6"
  status-gray-text: "#4b5563"
typography:
  display:
    fontFamily: "ui-sans-serif, system-ui, -apple-system, sans-serif"
    fontSize: "1.5rem"
    fontWeight: 700
    lineHeight: 1.25
    letterSpacing: "-0.01em"
  headline:
    fontFamily: "ui-sans-serif, system-ui, -apple-system, sans-serif"
    fontSize: "1.25rem"
    fontWeight: 600
    lineHeight: 1.35
  title:
    fontFamily: "ui-sans-serif, system-ui, -apple-system, sans-serif"
    fontSize: "1rem"
    fontWeight: 600
    lineHeight: 1.5
  body:
    fontFamily: "ui-sans-serif, system-ui, -apple-system, sans-serif"
    fontSize: "0.875rem"
    fontWeight: 400
    lineHeight: 1.6
  label:
    fontFamily: "ui-sans-serif, system-ui, -apple-system, sans-serif"
    fontSize: "0.75rem"
    fontWeight: 600
    lineHeight: 1.25
    letterSpacing: "0.05em"
rounded:
  sm: "0.375rem"
  md: "0.5rem"
  lg: "0.75rem"
  xl: "1rem"
  pill: "9999px"
spacing:
  xs: "0.5rem"
  sm: "1rem"
  md: "1.5rem"
  lg: "2rem"
  xl: "3rem"
components:
  button-primary:
    backgroundColor: "{colors.charcoal}"
    textColor: "{colors.surface-white}"
    rounded: "{rounded.lg}"
    padding: "0.625rem 1rem"
  button-primary-hover:
    backgroundColor: "{colors.charcoal-mid}"
  button-ghost:
    backgroundColor: "transparent"
    textColor: "{colors.charcoal-mid}"
    rounded: "{rounded.lg}"
    padding: "0.5rem 1rem"
  button-danger:
    backgroundColor: "transparent"
    textColor: "{colors.status-red}"
    rounded: "{rounded.lg}"
    padding: "0.5rem 1rem"
  input-default:
    backgroundColor: "{colors.surface-white}"
    textColor: "{colors.charcoal}"
    rounded: "{rounded.lg}"
    padding: "0.5rem 0.75rem"
  card-default:
    backgroundColor: "{colors.surface-white}"
    rounded: "{rounded.lg}"
    padding: "{spacing.sm}"
  badge-active:
    backgroundColor: "{colors.status-green-bg}"
    textColor: "{colors.status-green}"
    rounded: "{rounded.pill}"
    padding: "0.125rem 0.5rem"
  badge-revoked:
    backgroundColor: "{colors.status-red-bg}"
    textColor: "{colors.status-red}"
    rounded: "{rounded.pill}"
    padding: "0.125rem 0.5rem"
  badge-closed:
    backgroundColor: "{colors.status-gray-bg}"
    textColor: "{colors.status-gray-text}"
    rounded: "{rounded.pill}"
    padding: "0.125rem 0.5rem"
---

# Design System: Anfitriar

## Overview

**Creative North Star: "O Painel do Anfitrião"**

Anfitriar é a mesa de trabalho de quem gerencia hospedagens com seriedade. O sistema visual parte dessa metáfora: um painel de controle funcional, denso o suficiente para revelar informação sem ruído, limpo o suficiente para nunca intimidar. A interface não compete com o conteúdo — ela o serve. Cada tela tem uma tarefa clara; o design deixa essa tarefa óbvia.

O caráter dominante é cinza-quase-branco, bordas finas, tipografia preta em fundo branco. Sem gradientes, sem sombras pesadas, sem cores de marca invasivas. O Charcoal (`#111827`) é a única voz de cor dominante — ele aparece em botões primários, textos de ação e no logotipo. Seu papel é sinalizar "isso importa, faça isso agora". As cores de estado (verde, vermelho) existem para comunicar status, nunca para decorar.

A densidade é calibrada: formulários respiram, listas têm ritmo, cards têm padding honesto. O Anfitriar não é um dashboard luxuoso — é uma ferramenta que respeita o tempo de quem tem imóveis para administrar.

**Key Characteristics:**
- Fundo base cinza muito claro (`#f9fafb`) com superfícies brancas puras para cards e painéis
- Bordas 1px `#e5e7eb` como único mecanismo de profundidade — zero sombras no estado de repouso
- Charcoal puro como único acento dominante; cores de status com uso cirúrgico
- Tipografia system-ui: rápida, sem dependência de fonte externa, legível em qualquer dispositivo
- Raio de canto consistente em `0.5rem` (md) como padrão para cards e inputs; `0.375rem` (sm) para badges e chips
- Espaçamento baseado em múltiplos de `0.5rem`; ritmo vertical previsível

## Colors

Paleta monocromática cinza-sobre-branco com Charcoal como único acento e cores de estado funcionais.

### Primary
- **Charcoal** (`#111827`): Cor dominante de ação. Botões primários, textos de header, logotipo, bordas de foco, hover de links de ação. Não é uma cor de marca decorativa — é o peso visual da intenção.
- **Charcoal Deep** (`#030712`): Hover e pressed do botão primário. Reservado para estados de ativação.
- **Charcoal Mid** (`#374151`): Ícones, textos secundários de peso, rótulos de formulário.

### Neutral
- **Surface White** (`#ffffff`): Fundo de cards, modais, formulários, nav. A superfície de trabalho.
- **Surface Base** (`#f9fafb`): Fundo do body, cabeçalhos de tabela (`thead`), campos de input somente-leitura. Distingue hierarquia sem usar sombra.
- **Border Subtle** (`#e5e7eb`): Divisores de seção, bordas de card, separadores de tabela. O único mecanismo de profundidade do sistema.
- **Border Input** (`#d1d5db`): Contorno de inputs e textareas em estado padrão.
- **Slate Text** (`#6b7280`): Textos de suporte, meta-informações, labels de campo vazios, copy explicativo.
- **Slate Muted** (`#9ca3af`): Placeholders, estados desabilitados, textos terciários.

### Status
- **Green Active** (`#166534` sobre `#f0fdf4`): Badge "Link ativo". Uso restrito a status de reserva ativa.
- **Red Revoked** (`#991b1b` sobre `#fef2f2`): Badge "Link revogado", erros de formulário, alertas. Nunca para decoração.
- **Gray Closed** (`#4b5563` sobre `#f3f4f6`): Badge "Encerrada". Reservas inativas, categorias padrão (modo referência).

### Named Rules
**A Regra do Acento Único.** Charcoal é o único acento dominante. Cores de status (verde, vermelho) aparecem exclusivamente para comunicar estado de dados — nunca como elemento decorativo, hover de marketing, ou ênfase editorial.

## Typography

**Display / Body Font:** `ui-sans-serif, system-ui, -apple-system, BlinkMacSystemFont, sans-serif`

**Character:** Stack nativo de sistema operacional. Zero latência de carregamento, legibilidade máxima no dispositivo do usuário, sem impressão de marca tipográfica forte — o texto se apaga, o conteúdo fica.

### Hierarchy
- **Display** (700, 1.5rem, line-height 1.25, tracking −0.01em): Título de página (h1). Uma por tela. "Hospedagens", "Nova reserva", "Minha conta".
- **Headline** (600, 1.25rem, line-height 1.35): Seção de destaque dentro de página (h2 de bloco principal). "Guia do hóspede", "Link de acesso do hóspede".
- **Title** (600, 1rem, line-height 1.5): Subtítulos de card, rótulos de seção com peso. Nome do hóspede na listagem de reserva.
- **Body** (400, 0.875rem, line-height 1.6): Todo o conteúdo corrido, inputs, dados de tabela. Máximo de ~70ch por linha para leitura.
- **Label** (600, 0.75rem, line-height 1.25, tracking 0.05em, uppercase): Cabeçalhos de seção secundária ("ATIVAS E FUTURAS", "PADRÃO DO SISTEMA"). Nunca em bold + uppercase + colorido ao mesmo tempo.

### Named Rules
**A Regra da Hierarquia Plana.** Uma tela tem exatamente um h1 (Display). Seções de suporte usam h2 Label ou h2 Headline — nunca dois h1, nunca h2 mais pesado que h1. A hierarquia é estrutural, não decorativa.

## Layout

Container máximo `max-w-4xl` (56rem) centralizado, com `px-4 py-8` em mobile e `sm:px-6` em tablet+. Sem grid de colunas múltiplas no layout global — a interface é coluna única com bloco central.

Internamente, formulários são `max-w-lg` (32rem) para manter linhas curtas e escaneáveis. Tabelas e listas ocupam largura total do container. Cards de detalhes são blocos `rounded-lg border bg-white p-4` empilhados verticalmente com `space-y-6` ou `mt-6`.

**Breakpoints:** `sm` em 640px (Tailwind padrão). A maioria das vistas é responsiva por natureza (coluna única → sem quebra significativa).

**Ritmo vertical:** múltiplos de `0.5rem`. Margens entre seções: `mb-6` (1.5rem). Espaçamento entre campos de formulário: `space-y-5`. Padding interno de card: `p-4` (1rem).

**Grade de listagens:** `grid gap-2 sm:grid-cols-2` para categorias e chips. Tabelas com `overflow-x-auto` para proteção em mobile.

**Named Rules:**
**A Regra da Coluna Única.** O layout global nunca quebra em múltiplas colunas paralelas de conteúdo. Barras laterais, painéis divididos e layouts de dashboard multi-coluna não existem neste sistema. Toda a complexidade vive dentro de uma coluna central controlada.

## Elevation & Depth

Superfícies completamente planas em estado de repouso. Profundidade é dada exclusivamente por diferença de fundo (branco vs. `#f9fafb`) e bordas 1px `#e5e7eb`. Não há `box-shadow` em estado padrão de nenhum componente.

A única exceção são os cards de autenticação (login, cadastro, recuperação de senha): `shadow-sm` (`0 1px 2px 0 rgb(0 0 0 / 0.05)`) para destacar o formulário flutuante sobre o fundo cinza. Essa sombra nunca migra para componentes dentro da área autenticada.

Foco visível usa `ring-2 ring-gray-900 ring-offset-2` — uma borda de anel preta, não uma sombra. Consistente com o sistema plano.

### Named Rules
**A Regra do Plano por Padrão.** Sombras não existem na área autenticada. A profundidade é um contrato de borda e fundo, nunca de sombra. Se um elemento precisa "se destacar", use borda, fundo ou peso tipográfico — não sombra.

## Shapes

Linguagem de canto consistentemente arredondada, nunca sharp, nunca excessiva.

- **`rounded-lg` (0.5rem):** Padrão para cards, inputs, textareas, selects, botões. O raio dominante do sistema.
- **`rounded-xl` (0.75rem) / `rounded-2xl` (1rem):** Apenas em cards de autenticação flutuantes (login, cadastro). Raio maior sinaliza "este elemento está acima do fluxo normal".
- **`rounded-full` (9999px):** Exclusivo para badges de status (Link ativo, Link revogado, Encerrada) e chips de categoria. Nunca em botões de ação.
- **Bordas:** 1px `solid`. Nunca 2px ou dashed em estado funcional. Dashed (`border-dashed border-gray-300`) é reservado exclusivamente para estados vazios (empty states).

**Named Rules:**
**A Regra do Dashed para Vazio.** Borda tracejada significa "nada aqui ainda". É o único sinal visual de estado vazio e nunca aparece em componentes com conteúdo real.

## Components

### Buttons

Botões são decisivos e contidos. Nenhum efeito de elevação — apenas transição de cor.

- **Shape:** `rounded-lg` (0.5rem)
- **Primary** (Charcoal `#111827`, texto branco, `px-4 py-2.5`, `font-medium`): Ação principal de tela — "Salvar", "Criar", "Entrar". Hover: `#374151`. Focus: `ring-2 ring-gray-900 ring-offset-2`.
- **Ghost / Outline** (fundo transparente, borda `border-gray-300`, texto `text-gray-700`, `px-4 py-2`): Ações secundárias — "Editar", "Copiar", "Cancelar". Hover: `bg-gray-50`.
- **Danger** (fundo transparente, borda `border-red-300`, texto `text-red-700`, `px-4 py-2`): Ações destrutivas — "Excluir". Hover: `bg-red-50`. Sempre com `data-turbo-confirm`.
- **Link-style** (sem borda, sem fundo, texto `text-gray-700`, transição de `hover:text-gray-900`): Logout, nav links. Não é um botão visualmente — é texto com ação.

### Badges / Status Chips

- **Shape:** `rounded-full`, `px-2 py-0.5`, `text-xs font-medium`
- **Ativo:** verde (`#f0fdf4` fundo, `#166534` texto)
- **Revogado:** vermelho (`#fef2f2` fundo, `#991b1b` texto)
- **Encerrada:** cinza (`#f3f4f6` fundo, `#4b5563` texto)

### Cards / Containers

- **Corner:** `rounded-lg` (0.5rem)
- **Background:** `#ffffff` sobre fundo `#f9fafb`
- **Border:** 1px `#e5e7eb` (border-gray-200)
- **Shadow:** nenhuma na área autenticada
- **Internal Padding:** `p-4` (1rem) para cards de conteúdo; `p-8` para cards de autenticação
- **Auth Cards:** `rounded-2xl shadow-sm` — única exceção ao sistema plano

### Inputs / Fields

- **Style:** fundo branco, borda 1px `#d1d5db`, `rounded-lg`, `text-sm`
- **Focus:** `border-gray-900` + `ring-1 ring-gray-900 outline-none` — borda preta + anel preto. Direto e claro.
- **Error:** borda `border-red-300`, mensagem de erro inline abaixo do campo
- **Read-only:** fundo `#f9fafb` (surface-base), borda mantida
- **Labels:** `text-sm font-medium text-gray-700`, sempre acima do campo, nunca flutuantes (sem floating labels)
- **Hint text:** `text-xs text-gray-500` abaixo do campo. Usado para instruções de formato (CPF, telefone).

### Navigation

- **Container:** `border-b border-gray-200 bg-white`, sticky implícita via posição no topo
- **Brand mark:** `text-lg font-semibold tracking-tight` Charcoal — apenas texto, sem ícone
- **Links:** `text-sm text-gray-700 hover:text-gray-900` — sem underline, sem background ativo, sem indicador de rota atual (sistema atual)
- **Logout:** `button_to` com estilo link `text-gray-500 hover:text-gray-900`
- **Mobile:** sem hamburger menu implementado; nav colapsa naturalmente em tela pequena (overflow horizontal)

### Progress Indicator

Indicador de completude do guia: texto "X de Y categorias preenchidas" com número em `font-semibold text-gray-900`. Sem barra de progresso visual — o número é a métrica. Componente de texto puro.

### Empty States

- **Border:** `rounded-lg border border-dashed border-gray-300`
- **Padding:** `p-8`
- **Text:** `text-center text-gray-500 text-sm` (listas) ou `text-gray-600` (main content)
- **CTA inline:** link sublinhado dentro do texto do empty state — sem botão separado

### Section Headers (Label style)

Cabeçalhos de seção secundária: `text-sm font-semibold uppercase tracking-wide text-gray-500`. Usados como separadores de grupo ("ATIVAS E FUTURAS", "PADRÃO DO SISTEMA"). Nunca com borda ou background.

## Do's and Don'ts

### Do:
- **Do** usar `rounded-lg` (0.5rem) como raio padrão de cards, inputs e botões — é o único raio aprovado para componentes funcionais.
- **Do** reservar `border-dashed border-gray-300` exclusivamente para empty states. É o sinal visual de "nada aqui".
- **Do** usar `ring-2 ring-gray-900 ring-offset-2` em todos os estados de foco — nunca `outline: none` sem substituto acessível.
- **Do** manter bordas 1px `#e5e7eb` como único mecanismo de profundidade dentro da área autenticada.
- **Do** usar `font-medium text-white bg-gray-900` para o botão primário — sem gradientes, sem sombras, sem ícones decorativos.
- **Do** escrever rótulos de seção secundária em uppercase + tracking-wide + gray-500: é o único lugar onde uppercase é aprovado.
- **Do** usar `text-xs text-gray-500` para hints de campo logo abaixo do input.

### Don't:
- **Don't** adicionar `box-shadow` em cards, inputs ou botões na área autenticada — zero sombras é invariante do sistema.
- **Don't** usar `rounded-full` em botões de ação — `rounded-full` é exclusivo de badges de status e chips.
- **Don't** introduzir gradientes, múltiplas cores de acento ou cores fora da paleta definida.
- **Don't** criar layouts com múltiplas colunas paralelas — o sistema é coluna única por princípio.
- **Don't** usar floating labels ou labels inline dentro de inputs — labels ficam sempre acima do campo.
- **Don't** usar `font-bold` em textos de corpo — peso máximo de body text é `font-medium`. Bold é para Display e Headline.
- **Don't** aplicar `shadow-sm` (o shadow de auth cards) em componentes dentro do fluxo autenticado.
