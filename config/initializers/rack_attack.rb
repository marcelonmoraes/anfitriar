class Rack::Attack
  # Rate limit guest verification attempts (5 requests per minute per IP)
  throttle("guest_verification/ip", limit: 5, period: 1.minute) do |req|
    req.ip if req.path.match?(/\/g\/[^\/]+\/verify/) && req.post?
  end

  # Rate limit general guide access (30 requests per minute per IP)
  throttle("guide_access/ip", limit: 30, period: 1.minute) do |req|
    req.ip if req.path.match?(/\/g\/[^\/]+$/) && req.get?
  end

  # Protege o webhook do Asaas contra flood (o volume normal é baixo).
  throttle("asaas_webhook/ip", limit: 60, period: 1.minute) do |req|
    req.ip if req.path == "/webhooks/asaas" && req.post?
  end

  # Custom response for rate limited requests
  self.throttled_responder = lambda do |env|
    retry_after = (env["rack.attack.match_data"] || {})[:period] || 60
    headers = { "Retry-After" => retry_after.to_s }

    # Clientes de API (como o webhook do Asaas) recebem resposta enxuta.
    unless env["PATH_INFO"].start_with?("/g/")
      return [ 429, headers.merge("Content-Type" => "text/plain"), [ "Too many requests\n" ] ]
    end

    [
      429,
      headers.merge("Content-Type" => "text/html; charset=utf-8"),
      [ ApplicationController.render(
        template: "public_guides/rate_limited",
        layout: "public_guide",
        locals: { retry_after: retry_after }
      ) ]
    ]
  end
end

# Log blocked requests
ActiveSupport::Notifications.subscribe("rack.attack") do |name, start, finish, request_id, payload|
  req = payload[:request]
  Rails.logger.warn "[Rack::Attack] #{payload[:match_type]} #{payload[:discriminator]} from #{req.ip} - #{req.request_method} #{req.fullpath}"
end
