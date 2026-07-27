import { Controller } from "@hotwired/stimulus"

// Modo cascada: al entrar salta a la página donde se había quedado, y a
// medida que se hace scroll reporta (con debounce) cuál es la página
// visible para que el progreso quede guardado sin depender de "Siguiente".
export default class extends Controller {
  static targets = ["page"]
  static values = { initialPage: Number, progressUrl: String }

  connect() {
    // Turbo restablece el scroll a 0 al completar una visita (link normal o
    // submit), y lo hace después de que este controller ya se conectó, así
    // que un scrollIntoView() síncrono acá queda pisado. Se difiere a después
    // del siguiente repintado, cuando la restauración de Turbo ya ocurrió.
    requestAnimationFrame(() => {
      requestAnimationFrame(() => this.pageTargets[this.initialPageValue]?.scrollIntoView())
    })

    this.observer = new IntersectionObserver(this.handleIntersect.bind(this), { threshold: 0.5 })
    this.pageTargets.forEach((page) => this.observer.observe(page))
  }

  disconnect() {
    this.observer?.disconnect()
    clearTimeout(this.debounceTimer)
  }

  handleIntersect(entries) {
    const visible = entries.filter((entry) => entry.isIntersecting)
    if (visible.length === 0) return

    const topMost = visible.reduce((a, b) =>
      Number(a.target.dataset.pageNumber) < Number(b.target.dataset.pageNumber) ? a : b
    )
    this.currentPage = Number(topMost.target.dataset.pageNumber)

    clearTimeout(this.debounceTimer)
    this.debounceTimer = setTimeout(() => this.reportProgress(), 800)
  }

  reportProgress() {
    if (this.currentPage === undefined) return

    fetch(this.progressUrlValue, {
      method: "PATCH",
      headers: {
        "Content-Type": "application/json",
        "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]')?.content
      },
      body: JSON.stringify({ page: this.currentPage })
    })
  }
}
