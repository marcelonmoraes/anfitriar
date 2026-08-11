import { Controller } from "@hotwired/stimulus"
import Sortable from "sortablejs"

export default class extends Controller {
  static values = { url: String }

  connect() {
    this.sortable = Sortable.create(this.element, {
      handle: "[data-sortable-handle]",
      animation: 150,
      onEnd: () => this.save()
    })
  }

  disconnect() {
    this.sortable?.destroy()
  }

  async save() {
    const categoryIds = Array.from(this.element.querySelectorAll("[data-category-id]"))
      .map((element) => element.dataset.categoryId)

    try {
      const response = await fetch(this.urlValue, {
        method: "PATCH",
        headers: {
          "Content-Type": "application/json",
          "X-CSRF-Token": document.querySelector("meta[name='csrf-token']")?.content
        },
        body: JSON.stringify({ category_ids: categoryIds })
      })

      if (!response.ok) throw new Error(response.statusText)

      this.announce("Ordem salva.")
    } catch {
      // Sem aviso, o anfitrião acredita que a ordem foi salva e envia o guia
      // ao hóspede na sequência errada.
      this.announce("Não foi possível salvar a ordem. Recarregue a página e tente de novo.", true)
    }
  }

  announce(message, failed = false) {
    let status = this.element.parentElement.querySelector("[data-sortable-status]")

    if (!status) {
      status = document.createElement("p")
      status.dataset.sortableStatus = ""
      status.setAttribute("role", "status")
      status.setAttribute("aria-live", "polite")
      this.element.parentElement.insertBefore(status, this.element)
    }

    status.className = failed
      ? "mb-3 rounded-lg border border-red-200 bg-red-50 px-4 py-2 text-sm text-red-800"
      : "mb-3 rounded-lg border border-gray-200 bg-gray-50 px-4 py-2 text-sm text-gray-600"
    status.textContent = message

    clearTimeout(this.statusTimeout)
    if (!failed) {
      this.statusTimeout = setTimeout(() => status.remove(), 2500)
    }
  }
}
