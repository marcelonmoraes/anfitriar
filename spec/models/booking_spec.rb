require "rails_helper"

RSpec.describe Booking do
  it "gera token de acesso na criação" do
    booking = create(:booking)
    expect(booking.access_token).to be_present
    expect(booking.access_token.length).to be >= 24
  end

  it "exige check-out depois do check-in" do
    booking = build(:booking, check_in: Date.current, check_out: Date.current)
    expect(booking).not_to be_valid
    expect(booking.errors[:check_out]).to be_present
  end

  it "rejeita cliente de outro anfitrião" do
    booking = build(:booking, guest: create(:guest))
    expect(booking).not_to be_valid
    expect(booking.errors[:guest]).to be_present
  end

  describe "janela de acesso (margem padrão: 2 dias)" do
    it "calcula accessible_until e link_active?" do
      booking = create(:booking, check_in: Date.current - 5, check_out: Date.current - 1)
      expect(booking.accessible_until).to eq(Date.current + 1)
      expect(booking).to be_link_active

      expired = create(:booking, check_in: Date.current - 10, check_out: Date.current - 3)
      expect(expired).not_to be_link_active
    end
  end

  describe "revogação" do
    it "revoke! desativa o link" do
      booking = create(:booking)
      booking.revoke!
      expect(booking).to be_revoked
      expect(booking).not_to be_link_active
    end

    it "reissue! troca o token e reativa" do
      booking = create(:booking)
      booking.revoke!
      old_token = booking.access_token

      booking.reissue!
      expect(booking.access_token).not_to eq(old_token)
      expect(booking).to be_link_active
    end
  end

  describe "scopes" do
    it "separa reservas na janela das encerradas" do
      current = create(:booking, check_in: Date.current - 3, check_out: Date.current - 1)
      finished = create(:booking, check_in: Date.current - 10, check_out: Date.current - 5)

      expect(described_class.within_window).to include(current)
      expect(described_class.within_window).not_to include(finished)
      expect(described_class.finished).to include(finished)
      expect(described_class.finished).not_to include(current)
    end
  end
end
