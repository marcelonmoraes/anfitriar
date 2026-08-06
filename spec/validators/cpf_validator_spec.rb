require "rails_helper"

RSpec.describe CpfValidator do
  describe ".valid?" do
    it "aceita CPF válido" do
      expect(described_class.valid?("39053344705")).to be true
      expect(described_class.valid?("390.533.447-05")).to be true
    end

    it "rejeita dígitos verificadores errados" do
      expect(described_class.valid?("39053344706")).to be false
    end

    it "rejeita sequências repetidas e tamanhos errados" do
      expect(described_class.valid?("11111111111")).to be false
      expect(described_class.valid?("123")).to be false
      expect(described_class.valid?("")).to be false
    end
  end

  describe ".generate" do
    it "gera CPFs válidos e distintos" do
      first = described_class.generate(1)
      second = described_class.generate(2)
      expect(described_class.valid?(first)).to be true
      expect(described_class.valid?(second)).to be true
      expect(first).not_to eq(second)
    end
  end
end
