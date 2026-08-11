import { Controller } from "@hotwired/stimulus"

// O <details> guarda o estado aberto no DOM, e o Turbo restaura esse DOM ao
// navegar. Sem isto, o menu reaparece aberto na próxima página.
export default class extends Controller {
  connect() {
    this.close = this.close.bind(this)
    document.addEventListener("turbo:before-cache", this.close)
  }

  disconnect() {
    document.removeEventListener("turbo:before-cache", this.close)
  }

  toggled() {
    if (this.element.open) {
      this.escapeListener ||= (event) => {
        if (event.key === "Escape") {
          this.close()
          this.element.querySelector("summary")?.focus()
        }
      }
      document.addEventListener("keydown", this.escapeListener)
    } else if (this.escapeListener) {
      document.removeEventListener("keydown", this.escapeListener)
    }
  }

  close() {
    this.element.open = false
  }
}
