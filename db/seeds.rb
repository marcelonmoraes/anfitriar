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

# Categorias padrão do sistema (spec §2.3)
[
  "Wi-Fi", "Check-in/Check-out", "Como chegar", "Regras da casa", "Manual da casa",
  "Telefones úteis", "Emergências", "Restaurantes", "Mercados e farmácias",
  "Passeios e atrações", "Transporte"
].each_with_index do |name, index|
  category = Category.standard.find_or_initialize_by(name: name)
  category.update!(position: index + 1)
end

# Host de desenvolvimento
if Rails.env.development?
  host = Host.find_or_initialize_by(email_address: "admin@anfitriar.local")
  host.assign_attributes(
    name: "Admin Desenvolvimento",
    phone: "11999999999",
    password: "senha123",
    password_confirmation: "senha123"
  )
  host.save!

  # Subscription trial Pro (7 dias)
  pro_plan = Plan.find_by(slug: "pro")
  Subscription.find_or_create_by!(host: host) do |sub|
    sub.plan = pro_plan
    sub.billing_cycle = "monthly"
    sub.status = "trial"
    sub.trial_ends_at = 7.days.from_now
  end
end
