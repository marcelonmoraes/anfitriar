module BookingsHelper
  def guide_link_for(booking)
    public_guide_url(token: booking.access_token)
  end

  def whatsapp_share_url(booking)
    message = "Olá, #{booking.guest.name}! Aqui está o guia digital da sua hospedagem " \
              "em #{booking.property.name}: #{guide_link_for(booking)}"
    "https://wa.me/55#{booking.guest.phone}?text=#{ERB::Util.url_encode(message)}"
  end
end
