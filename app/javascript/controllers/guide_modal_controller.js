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
    const card = event.currentTarget
    const title = card.dataset.guideModalTitleValue
    const content = card.dataset.guideModalContentValue

    this.titleTarget.textContent = title
    this.bodyTarget.innerHTML = content
    this.modalTarget.showModal()

    // Focus trap for accessibility
    this.previousFocus = document.activeElement
    this.modalTarget.querySelector(".modal-close").focus()

    // Prevent body scroll
    document.body.style.overflow = "hidden"

    // Listen for Escape key
    document.addEventListener("keydown", this.handleKeydownBound)
  }

  close() {
    this.modalTarget.close()
    document.body.style.overflow = ""

    // Restore focus to the card that was clicked
    if (this.previousFocus) {
      this.previousFocus.focus()
    }

    document.removeEventListener("keydown", this.handleKeydownBound)
  }

  handleKeydown(event) {
    if (event.key === "Escape") {
      this.close()
    }
  }
}