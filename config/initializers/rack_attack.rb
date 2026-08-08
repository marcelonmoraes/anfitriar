class Rack::Attack
  # Rate limit guest verification attempts (5 requests per minute per IP)
  throttle("guest_verification/ip", limit: 5, period: 1.minute) do |req|
    req.ip if req.path.match?(/\/g\/[^\/]+\/verify/) && req.post?
  end

  # Rate limit general guide access (30 requests per minute per IP)
  throttle("guide_access/ip", limit: 30, period: 1.minute) do |req|
    req.ip if req.path.match?(/\/g\/[^\/]+$/) && req.get?
  end

  # Custom response for rate limited requests
  self.throttled_responder = lambda do |env|
    retry_after = (env["rack.attack.match_data"] || {})[:period] || 60
    [
      429,
      { "Content-Type" => "text/html; charset=utf-8", "Retry-After" => retry_after.to_s },
      [ApplicationController.render(
        template: "public_guides/rate_limited",
        layout: "public_guide",
        locals: { retry_after: retry_after }
      )]
    ]
  end
end

# Log blocked requests
ActiveSupport::Notifications.subscribe("rack.attack") do |name, start, finish, request_id, payload|
  req = payload[:request]
  Rails.logger.warn "[Rack::Attack] #{payload[:match_type]} #{payload[:discriminator]} from #{req.ip} - #{req.request_method} #{req.fullpath}"
end