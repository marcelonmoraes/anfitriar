# Product

<!-- impeccable:product-schema 1 -->

## Platform

web

## Stack

Rails 8.1 (Ruby 4.0), PostgreSQL, Hotwire (Turbo + Stimulus), Tailwind CSS, Propshaft, importmap-rails, Solid Queue/Cache/Cable, Action Text (Trix). Deploy target: Linux server (VPS/container).

## Users

**Primary:** Anfitriões (hosts) de aluguel por temporada — inicialmente anfitriões do Airbnb, expansão futura para Booking, aluguel direto e pousadas.  
**Secondary:** Hóspedes (guests) — acessam o guia via link público `/g/:token`, sem login.  
**Admin (Owner):** Equipe do Anfitriar — gerencia planos, categorias padrão, assinaturas manuais e analytics agregados (Subprojeto 2).

Situação: anfitrião recebe reserva → cadastra hóspede → gera link → hóspede abre guia → confirma CPF + 4 dígitos telefone → acessa conteúdo.  
Job: transformar a experiência de check-in em um guia digital profissional, bonito e confiável, sem depender de WhatsApp/PDF.

## Product Purpose

SaaS para anfitriões criarem guias digitais elegantes de suas hospedagens.  
O anfitrião cadastra a hospedagem, preenche cards por categoria (Wi-Fi, check-in, restaurantes etc.), cadastra hóspedes e gera links de acesso por reserva. O hóspede abre o link, confirma identidade e vê o guia.

Success: anfitrião ativa trial → cria 1+ hospedagem → preenche guia → gera 1+ reserva com link → hóspede acessa sem fricção. Métricas: taxa de ativação trial→pago, % guias preenchidos, NPS anfitrião/hóspede.

## Positioning

Único guia digital por reserva com:  
- Acesso tokenizado com expiração automática pós-check-out + margem configurável  
- Verificação de identidade do hóspede (CPF + 4 dígitos telefone) sem login  
- Cards reordenáveis/ocultáveis por hospedagem + categorias próprias reutilizáveis  
- Preview "ver como hóspede" antes de enviar  
- Modelo volume: entrada barata (R$ 19,90), upgrade natural por nº de imóveis

Concorrentes (PDF, Notion, WhatsApp, guias impressos) não têm verificação de identidade, expiração automática nem estrutura por reserva.

## Operating Context

- Anfitrião usa desktop/tablet para montar guia (área autenticada)
- Hóspede usa mobile na hora do check-in (link público)
- Contexto de uso: urgência no check-in, conexão instável, pouca atenção
- LGPD: PII do hóspede (CPF, telefone) criptografada no banco, exibida mascarada
- Idioma: 100% PT-BR no MVP (interface e conteúdo)

## Capabilities and Constraints

**Built (Subprojeto 1):**
- Auth Host: cadastro, login, logout, recuperação senha, trial 7 dias auto (plano Pro)
- Hospedagens: CRUD com foto de capa, limite por plano
- Guias: editor Action Text por card, drag-to-reorder, toggle ocultar, progresso preenchimento
- Clientes: CRUD com validação CPF (dígito verificador), máscara, criptografia determinística
- Categorias: padrão do sistema (11, gerenciadas no Admin) + próprias do anfitrião
- Reservas: criar (hospedagem + cliente + datas) → link + botões copiar/WhatsApp; revogar/regenerar; listas ativas/futuras/encerradas
- Preview bruto (sem confirmação CPF)
- Conta: dados do anfitrião + status trial/assinatura
- Seeds: 11 categorias padrão, planos Essencial/Pro

**Planned:**
- Subprojeto 2: Admin (Owner auth, CRUD planos/categorias padrão, gestão anfitriões, assinaturas manuais, analytics, dashboard financeiro)
- Subprojeto 3: Guia visual hóspede (cards elegantes, confirmação CPF/4 dígitos, cookie por reserva, rate limiting, páginas link inválido/expirado)
- Subprojeto 4: Asaas (checkout no site, webhooks, ciclo trial→ativo→inadimplente→bloqueio)

**Constraints:**
- Monolito Rails, tenancy por `Current.host` (row-level), sem subdomínio
- Autenticação nativa Rails (`has_secure_password`), sessões em banco, identidades separadas por contexto
- PII com Active Record Encryption, filtros de log
- Sem Devise, sem Sidekiq (Solid Queue), sem webpack (importmap + Propshaft)

## Brand Commitments

**Name:** Anfitriar (definitivo)  
**Voice:** Profissional e confiável — ferramenta séria para quem gerencia imóveis como negócio  
**Visual identity:** Ainda não definida (sem logo, cores, tipografia)  
**Tagline:** Nenhuma oficial

## Evidence on Hand

- Spec consolidada: `docs/superpowers/specs/2026-08-06-anfitriar-plataforma-design.md`
- Código funcional: autenticação, hospedagens, guias, clientes, categorias, reservas, preview, conta
- Testes: RSpec model/request specs passando (91 exemplos), system specs precisam selenium-webdriver
- Assets: Tailwind v4, Trix/Action Text, importmap, sem build step JS

**Ausências que futuros não devem inventar:** logo, paleta de cores, tipografia, screenshots reais de guias preenchidos, depoimentos de clientes, métricas de conversão, benchmarks de concorrentes.

## Product Principles

1. **Confiabilidade acima de tudo** — o guia precisa abrir sempre, expirar no momento certo, não vazar dados do hóspede
2. **Volume, não features premium** — preço de entrada baixo, limite de imóveis é o gatilho natural de upgrade; categorias próprias no plano básico
3. **Zero fricção pro hóspede** — sem cadastro, sem app, sem login; token + CPF/4 dígitos é o contrato
4. **O anfitrião manda no conteúdo** — categorias padrão como referência, próprias reutilizáveis, ordem/visibilidade por hospedagem
5. **Código em inglês, interface em português** — domínio técnico universal, experiência local impecável

## Accessibility & Inclusion

- WCAG 2.1 AA como padrão (contraste, foco visível, labels, landmarks)
- Mobile-first: hóspede acessa em celular no momento do check-in
- CPF como credencial pressupõe hóspede brasileiro no MVP
- Textos em PT-BR; preparação para i18n futura (rails-i18n instalado)