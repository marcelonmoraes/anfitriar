class Current < ActiveSupport::CurrentAttributes
  attribute :session
  delegate :host, to: :session, allow_nil: true
end
