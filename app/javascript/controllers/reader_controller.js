import { Controller } from "@hotwired/stimulus"

// Navegación con flechas del teclado en el lector de páginas.
export default class extends Controller {
  static values = { previousUrl: String, nextUrl: String }

  connect() {
    this.handleKeydown = this.handleKeydown.bind(this)
    document.addEventListener("keydown", this.handleKeydown)
  }

  disconnect() {
    document.removeEventListener("keydown", this.handleKeydown)
  }

  handleKeydown(event) {
    if (event.key === "ArrowLeft" && this.previousUrlValue) {
      Turbo.visit(this.previousUrlValue)
    } else if (event.key === "ArrowRight" && this.nextUrlValue) {
      Turbo.visit(this.nextUrlValue)
    }
  }
}
