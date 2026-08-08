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

    await fetch(this.urlValue, {
      method: "PATCH",
      headers: {
        "Content-Type": "application/json",
        "X-CSRF-Token": document.querySelector("meta[name='csrf-token']").content
      },
      body: JSON.stringify({ category_ids: categoryIds })
    })
  }
}
