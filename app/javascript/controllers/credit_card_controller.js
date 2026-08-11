import { Controller } from "@hotwired/stimulus"

// Formata e valida o cartão no cliente. O número nunca é enviado a lugar
// nenhum além do POST do próprio formulário, que o repassa ao Asaas.
export default class extends Controller {
  static targets = ["number", "expiry", "cvv", "brand", "submit"]

  // Prefixos e comprimentos aceitos pelo Asaas.
  static BRANDS = [
    { name: "Visa", pattern: /^4/, length: 16, cvv: 3, gaps: [4, 8, 12] },
    { name: "Mastercard", pattern: /^(5[1-5]|2[2-7])/, length: 16, cvv: 3, gaps: [4, 8, 12] },
    { name: "Amex", pattern: /^3[47]/, length: 15, cvv: 4, gaps: [4, 10] },
    { name: "Elo", pattern: /^(4011|4312|4389|5041|5066|5090|6277|6362|6363)/, length: 16, cvv: 3, gaps: [4, 8, 12] },
    { name: "Hipercard", pattern: /^(606282|3841)/, length: 16, cvv: 3, gaps: [4, 8, 12] },
    { name: "Diners", pattern: /^3(0[0-5]|[68])/, length: 14, cvv: 3, gaps: [4, 10] }
  ]

  connect() {
    this.formatNumber()
  }

  formatNumber() {
    const digits = this.digitsOf(this.numberTarget)
    const brand = this.detectBrand(digits)
    const trimmed = digits.slice(0, brand ? brand.length : 19)

    this.numberTarget.value = this.groupDigits(trimmed, brand?.gaps || [4, 8, 12, 16])
    this.cvvTarget.maxLength = brand?.cvv || 4

    if (this.hasBrandTarget) {
      this.brandTarget.textContent = brand?.name || ""
    }
  }

  formatExpiry() {
    let digits = this.digitsOf(this.expiryTarget).slice(0, 4)

    // Mês digitado como "3" vira "03" automaticamente.
    if (digits.length === 1 && digits > "1") {
      digits = `0${digits}`
    }

    this.expiryTarget.value =
      digits.length > 2 ? `${digits.slice(0, 2)}/${digits.slice(2)}` : digits
  }

  formatCvv() {
    this.cvvTarget.value = this.digitsOf(this.cvvTarget).slice(0, this.cvvTarget.maxLength)
  }

  // Evita duplo clique gerando duas cobranças.
  submit() {
    if (!this.hasSubmitTarget) return

    this.submitTarget.disabled = true
    this.submitTarget.dataset.originalText = this.submitTarget.value
    this.submitTarget.value = "Processando..."
  }

  digitsOf(field) {
    return field.value.replace(/\D/g, "")
  }

  groupDigits(digits, gaps) {
    return digits
      .split("")
      .map((digit, index) => (gaps.includes(index) ? ` ${digit}` : digit))
      .join("")
  }

  detectBrand(digits) {
    return this.constructor.BRANDS.find((brand) => brand.pattern.test(digits))
  }
}
