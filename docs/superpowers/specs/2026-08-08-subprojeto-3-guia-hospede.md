# Subprojeto 3 — Guia do Hóspede (Público)

**Data:** 2026-08-08  
**Status:** Aprovado  
**Escopo:** Implementação da rota pública `/g/:token` que exibe o guia digital do hóspede com visual elegante em cards, confirmação de identidade via CPF + 4 dígitos do telefone, cookie por reserva, rate limiting e páginas de erro neutras.

---

## 1. Visão Geral

O Guia do Hóspede é a **superfície pública** do Anfitriar. É o momento de maior exposição da marca: o hóspede recebe o link no WhatsApp, abre no celular no momento do check-in e espera ver algo profissional, rápido e confiável.

Diferente da área do anfitrião (Operate) e do admin (Operate), esta superfície é **Experience + Persuade**: o artefato (o guia) deve "falar por si", a interface recede, e a experiência de leitura deve ser prazerosa e tranquila.

---

## 2. Decisões de Arquitetura & Segurança

### 2.1 Rota Pública
- **URL:** `/g/:token` (token = `Booking.access_token`, gerado via `has_secure_token`)
- **Controller:** `PublicGuidesController#show` (namespace raiz, sem `/admin` nem autenticação de Host)
- **Middleware:** Rate limiting via Rack::Attack (5 tentativas/minuto por IP na verificação CPF/telefone)

### 2.2 Fluxo de Acesso
1. Hóspede abre `/g/:token`
2. Se booking inexistente → **Página "Link Inválido"** (404 visual, sem vazar existência)
2. Se booking revogado → **Página "Link Revogado"** (neutra)
3. Se fora da janela (check-out + margem) → **Página "Acesso Encerrado"**
4. Se válido → Exibe **formulário de verificação**: CPF + 4 últimos dígitos do telefone
5. Se verificação OK → **Cookie assinado** (`guest_access_<token>`) com expiração = `accessible_until` do booking
6. Redirect para `/g/:token` → Renderiza **guia visual** (cards)

### 2.3 Cookie de Sessão do Hóspede
- Nome: `guest_access_<token>` (ex: `guest_access_a1b2c3d4`)
- Valor: `signed` (Rails `cookies.signed`), contém apenas `token` e `expires_at`
- Expiração: `booking.accessible_until` (check-out + margem configurável)
- `HttpOnly: true`, `Secure: true` (produção), `SameSite: :lax`
- Não armazena CPF/telefone — apenas prova de verificação

### 2.4 Privacidade & LGPD
- **Nunca** loga CPF ou telefone em texto plano
- Rate limiting protege contra enumeração de tokens
- Páginas de erro **não diferenciam** "token não existe" vs "token revogado" vs "fora da janela" — todas exibem mensagem neutra
- Cookie não contém PII

---

## 3. Interface do Guia (Visual)

### 3.1 North Star: "O Guia Editorial"
- **Modo:** Experience — o hóspede "lê" o guia, não "usa" uma ferramenta
- **Estética:** Editorial, arejada, tipografia generosa, espaçamento respirado
- **Cores:** Herda `DESIGN.md` (Charcoal accent, superfície branca, bordas sutis)
- **Mobile-first:** Single column, touch-friendly, leitura vertical natural

### 3.2 Componentes do Guia

#### Header (Sticky-top em scroll)
- Logo "Anfitriar" (Charcoal)
- Nome da hospedagem
- Badge sutil: "Check-in: DD/MM" — "Check-out: DD/MM"

#### Cards de Categoria (Ordem definida pelo anfitrião no guia)
- **Container:** `rounded-xl border border-gray-200 bg-white p-5` (mobile: `p-4`)
- **Título da Categoria:** `text-lg font-semibold text-gray-900` + ícone opcional (emoji SVG inline: 📶, 🔑, 🍽️, etc.)
- **Conteúdo:** `prose prose-gray max-w-none` (Action Text renderizado)
- **Divisor:** `border-t border-gray-100 my-5` entre cards (exceto último)

#### Empty States por Categoria
- Se categoria **oculta** ou **sem descrição** → **não renderiza** (não aparece no guia)

#### Footer Fixo (Bottom-bar mobile)
- Texto: "Desenvolvido com cuidado por Anfitriar"
- Link discreto: "Precisa de ajuda?" → mailto/suporte

### 3.3 Tipografia (Herda `DESIGN.md` + ajustes Experience)
- **Display (Nome da hospedagem):** `text-2xl font-bold tracking-tight`
- **Headline (Título do card):** `text-lg font-semibold`
- **Body (Conteúdo do card):** `text-base leading-relaxed` (Action Text via `.prose`)
- **Label (Datas/Badges):** `text-sm text-gray-500`

### 3.4 Espaçamento & Ritmo
- Padding vertical entre cards: `space-y-8` (mobile) / `space-y-10` (desktop)
- Padding lateral: `px-4` (mobile) / `px-6` (desktop)
- Max-width do container: `max-w-2xl` (≈ 42rem) — largura ideal de leitura

---

## 4. Fluxos de Erro (Páginas Neutras)

Todas as páginas de erro compartilham o mesmo layout base:

```
<main class="min-h-screen flex items-center justify-center px-4 py-12">
  <article class="max-w-md w-full text-center">
    <div class="mx-auto mb-4 h-16 w-16 rounded-2xl bg-gray-100 flex items-center justify-center">
      <svg class="h-8 w-8 text-gray-400" ...>...</svg>
    </div>
    <h1 class="text-xl font-bold text-gray-900">{Título}</h1>
    <p class="mt-2 text-sm text-gray-500">{Mensagem explicativa}</p>
    <p class="mt-4 text-xs text-gray-400">Anfitriar</p>
  </article>
</main>
```

| Cenário | Título | Mensagem |
|---------|--------|----------|
| Token não encontrado / revogado / inválido | "Link inválido" | "Este link de acesso não é válido ou foi revogado pelo anfitrião." |
| Fora da janela (check-out + margem) | "Acesso encerrado" | "O período de acesso a este guia expirou. Entre em contato com o anfitrião se precisar de informações." |
| Verificação falhou (CPF/telefone incorretos) | "Dados incorretos" | "O CPF ou os 4 dígitos do telefone não conferem. Verifique e tente novamente." |
| Rate limited | "Muitas tentativas" | "Você fez muitas tentativas recentemente. Aguarde alguns minutos e tente novamente." |

---

## 5. Modelos & Dados

### 5.1 `Booking` — Novos Métodos/Atributos
- `accessible_until` → `check_out + PlatformConfiguration.current.booking_access_margin_days.days`
- `link_active?` → `!revoked? && Date.current <= accessible_until`
- `verify_guest!(cpf, phone_last4)` → Compara CPF criptografado determinístico + últimos 4 dígitos do telefone

### 5.2 Rate Limiting (Rack::Attack)
```ruby
throttle('guest_verification/ip', limit: 5, period: 1.minute) do |req|
  req.ip if req.path.start_with?('/g/') && req.post?
end
```

---

## 6. Plano de Execução (Fases)

### **Fase 1: Fundação Pública & Verificação**
- Rota `GET /g/:token` → `PublicGuidesController#show`
- `GET /g/:token/verify` → Formulário CPF + 4 dígitos telefone
- `POST /g/:token/verify` → Verificação + set cookie signed + redirect
- Rate limiting (Rack::Attack)
- Páginas de erro neutras (inválido, encerrado, revogado)

### **Fase 2: Visual do Guia (Cards)**
- Renderização dos cards visuais (header fixo, cards ordenados, footer)
- Integração com Action Text (`.prose` styling)
- Empty states por categoria (ocultas/sem descrição não aparecem)
- Footer bottom-bar mobile

### **Fase 3: Testes & Hardening**
- Request specs: fluxo completo (token válido → verificação → guia)
- Request specs: fluxos de erro (inválido, expirado, revogado, rate limit)
- System spec: jornada do hóspede mobile
- Impeccable audit no visual público

---

## 7. Critérios de Aceite

1. ✅ Hóspede abre `/g/:token` válido → vê formulário CPF/telefone → confirma → vê guia visual
2. ✅ Cookie assinado persiste até `accessible_until`; reabrir link não pede verificação novamente
3. ✅ Token revogado / expirado / inexistente → página neutra (sem diferenciar casos)
4. ✅ 5 tentativas falhas/minuto → rate limit bloqueia com página "Muitas tentativas"
5. ✅ Guia renderiza apenas categorias preenchidas e não ocultas, na ordem do anfitrião
6. ✅ Visual mobile-first: largura ≤ 42rem, tipografia legível, touch targets ≥ 44px
7. ✅ Zero PII nos logs; CPF/telefone nunca em texto plano
8. ✅ 100% request specs cobrindo fluxos de sucesso e erro
9. ✅ Impeccable audit: 20/20 na superfície pública