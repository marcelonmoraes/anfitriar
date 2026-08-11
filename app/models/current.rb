class Current < ActiveSupport::CurrentAttributes
  attribute :session
  attribute :standard_categories
  delegate :host, to: :session, allow_nil: true
end
