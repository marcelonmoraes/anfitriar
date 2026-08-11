import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["source", "button"]

  async copy() {
    try {
      await this.write(this.sourceTarget.value)
      this.feedback("Copiado!")
    } catch {
      // Clipboard API exige contexto seguro e permissão. Quando falha, o
      // hóspede ainda precisa do link: selecionamos o texto para cópia manual.
      this.sourceTarget.focus()
      this.sourceTarget.select()
      this.feedback("Copie com Ctrl+C")
    }
  }

  async write(text) {
    if (navigator.clipboard?.writeText) {
      return navigator.clipboard.writeText(text)
    }
    throw new Error("Clipboard indisponível")
  }

  feedback(message) {
    if (!this.hasButtonTarget) return

    clearTimeout(this.resetTimeout)
    this.originalLabel ||= this.buttonTarget.textContent
    this.buttonTarget.textContent = message
    this.resetTimeout = setTimeout(() => {
      this.buttonTarget.textContent = this.originalLabel
    }, 2000)
  }

  disconnect() {
    clearTimeout(this.resetTimeout)
  }
}
