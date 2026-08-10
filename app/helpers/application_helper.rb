module ApplicationHelper
  def nav_link(label, path, id)
    active = current_page?(path)
    classes = "nav-link px-3 py-1.5 rounded-lg font-medium transition-colors focus:outline-none focus:ring-2 focus:ring-gray-900 focus:ring-offset-2 #{active ? 'bg-gray-100 text-gray-900' : 'text-gray-600 hover:text-gray-900 hover:bg-gray-50'}"
    link_to label, path, class: classes, id: id, "aria-current": active ? "page" : nil
  end

  def admin_nav_link(label, path, id)
    active = current_page?(path)
    classes = "nav-link px-3 py-1.5 rounded-lg font-medium transition-colors focus:outline-none focus:ring-2 focus:ring-gray-900 focus:ring-offset-2 #{active ? 'bg-red-50 text-red-700' : 'text-gray-600 hover:text-gray-900 hover:bg-gray-50'}"
    link_to label, path, class: classes, id: id, "aria-current": active ? "page" : nil
  end

  def category_icon(name)
    icon = case name.downcase
    when /wi.?fi|internet/ then "📶"
    when /check.?in|check.?out|chegada|saída/ then "🔑"
    when /como chegar|localização|endereço|mapa/ then "📍"
    when /regras|conduta|proibido/ then "📋"
    when /manual|casa|aparelho|eletro/ then "📖"
    when /telefone|útil|emergência|bombeiro|polícia|samu/ then "📞"
    when /restaurante|comida|delivery|comer/ then "🍽️"
    when /mercado|farmácia|farmacia|compras/ then "🛒"
    when /passeio|atração|turismo|praia|trilha/ then "🏖️"
    when /transporte|uber|ônibus|onibus|metro|trem/ then "🚌"
    else "📄"
    end
    content_tag(:span, icon, class: "text-lg", aria_hidden: "true")
  end
end
