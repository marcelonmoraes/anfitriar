require "rails_helper"

RSpec.describe PlatformConfiguration do
  describe ".current" do
    it "cria o registro único com os padrões da spec" do
      config = described_class.current
      expect(config.trial_days).to eq(7)
      expect(config.booking_access_margin_days).to eq(2)
    end

    it "reutiliza o mesmo registro em chamadas seguintes" do
      expect { 3.times { described_class.current } }.to change(described_class, :count).by(1)
    end
  end
end
