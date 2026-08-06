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
