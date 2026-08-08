import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["modal", "title", "body"]

  connect() {
    this.handleKeydownBound = this.handleKeydown.bind(this)
  }

  disconnect() {
    document.removeEventListener("keydown", this.handleKeydownBound)
  }

  open(event) {
    if (event) {
      if (event.type === "keydown" && (event.key === " " || event.key === "Spacebar")) {
        event.preventDefault()
      }
    }

    const card = event ? event.currentTarget : null
    if (!card) return

    const title = card.dataset.guideModalTitleValue || card.querySelector("h2")?.textContent?.trim() || ""

    // Find card content container
    const contentElement = card.querySelector("[data-guide-modal-target='cardContent'], template, .card-content-hidden")
    let content = ""

    if (contentElement) {
      content = contentElement.innerHTML
    } else if (card.dataset.guideModalContentValue) {
      content = card.dataset.guideModalContentValue
    }

    if (this.hasTitleTarget) {
      this.titleTarget.textContent = title
    }

    if (this.hasBodyTarget) {
      this.bodyTarget.innerHTML = content
    }

    const modalEl = this.hasModalTarget ? this.modalTarget : document.getElementById("guide-modal")
    if (modalEl) {
      modalEl.classList.remove("hidden")
      if (typeof modalEl.showModal === "function") {
        try { modalEl.showModal() } catch (e) {}
      }
    }

    this.previousFocus = document.activeElement
    if (modalEl) {
      const closeBtn = modalEl.querySelector(".modal-close") || modalEl.querySelector("button")
      if (closeBtn) {
        closeBtn.focus()
      }
    }

    document.body.style.overflow = "hidden"
    document.addEventListener("keydown", this.handleKeydownBound)
  }

  close() {
    const modalEl = this.hasModalTarget ? this.modalTarget : document.getElementById("guide-modal")
    if (modalEl) {
      if (typeof modalEl.close === "function" && modalEl.open) {
        try { modalEl.close() } catch (e) {}
      }
      modalEl.classList.add("hidden")
    }

    document.body.style.overflow = ""

    if (this.previousFocus && typeof this.previousFocus.focus === "function") {
      this.previousFocus.focus()
    }

    document.removeEventListener("keydown", this.handleKeydownBound)
  }

  handleKeydown(event) {
    if (event.key === "Escape") {
      this.close()
    }
  }

  backdropClick(event) {
    const modalEl = this.hasModalTarget ? this.modalTarget : document.getElementById("guide-modal")
    if (modalEl && event.target === modalEl) {
      this.close()
    }
  }
}