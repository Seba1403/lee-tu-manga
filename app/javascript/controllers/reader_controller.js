import { Controller } from "@hotwired/stimulus"

// Las imágenes precargadas se guardan a nivel de módulo y no en el controlador
// a propósito: Turbo reemplaza el <body> en cada visita, así que el controlador
// se destruye justo al pasar de página. Si las referencias vivieran en él, el
// navegador podría descartar la descarga que estaba en curso —la de la página
// que se está por mostrar—, que es exactamente la que queremos aprovechar.
const preloadedPages = new Map()
const MAX_PRELOADED_PAGES = 8

function preloadPage(url) {
  if (preloadedPages.has(url)) return

  const image = new Image()
  image.src = url
  preloadedPages.set(url, image)

  // Mantener acotada la memoria: se descartan las precargas más viejas, que
  // son las páginas de las que el lector ya se alejó.
  while (preloadedPages.size > MAX_PRELOADED_PAGES) {
    preloadedPages.delete(preloadedPages.keys().next().value)
  }
}

// Navegación con flechas del teclado y precarga de las páginas vecinas.
export default class extends Controller {
  static values = { previousUrl: String, nextUrl: String, preloadUrls: Array }

  connect() {
    this.handleKeydown = this.handleKeydown.bind(this)
    document.addEventListener("keydown", this.handleKeydown)
    this.preloadWhenCurrentPageIsVisible()
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

  // Recién cuando la página actual terminó de cargar: si se precargara antes,
  // las descargas de las páginas siguientes competirían por el ancho de banda
  // con la única que el lector está esperando ver ahora.
  preloadWhenCurrentPageIsVisible() {
    const currentPage = this.element.querySelector("img")

    if (!currentPage || currentPage.complete) {
      this.preloadNeighbourPages()
      return
    }

    currentPage.addEventListener("load", () => this.preloadNeighbourPages(), { once: true })
    currentPage.addEventListener("error", () => this.preloadNeighbourPages(), { once: true })
  }

  preloadNeighbourPages() {
    this.preloadUrlsValue.forEach(preloadPage)
  }
}
