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

// Modo inmersivo de respaldo para cuando no hay Fullscreen API (Safari en
// iPhone es el caso típico: sólo la expone para <video>). No apaga la barra
// del navegador, pero el lector igual pasa a ocupar toda la pantalla. Vive a
// nivel de módulo por el mismo motivo que las precargas: Turbo destruye el
// controlador al pasar de página y el modo tiene que sobrevivir a eso.
let immersiveFallback = false

const fullscreenElement = () =>
  document.fullscreenElement || document.webkitFullscreenElement

const fullscreenAvailable = () =>
  Boolean(document.fullscreenEnabled || document.webkitFullscreenEnabled)

// Se pide sobre <html> y no sobre el lector: al pasar de página Turbo saca del
// documento el elemento que estaba en pantalla completa y el navegador cierra
// el modo. <html> sobrevive a la visita, así que la lectura no se interrumpe.
function requestFullscreen() {
  const root = document.documentElement
  const request = root.requestFullscreen || root.webkitRequestFullscreen
  return request?.call(root)
}

function exitFullscreen() {
  const exit = document.exitFullscreen || document.webkitExitFullscreen
  return exit?.call(document)
}

// Navegación con flechas del teclado, pantalla completa y precarga de las
// páginas vecinas.
export default class extends Controller {
  static targets = ["image", "toggle"]
  static values = { previousUrl: String, nextUrl: String, preloadUrls: Array }

  connect() {
    this.handleKeydown = this.handleKeydown.bind(this)
    this.syncFullscreen = this.syncFullscreen.bind(this)

    document.addEventListener("keydown", this.handleKeydown)
    document.addEventListener("fullscreenchange", this.syncFullscreen)
    document.addEventListener("webkitfullscreenchange", this.syncFullscreen)

    // Al pasar de página se conecta un controlador nuevo con la pantalla
    // completa ya activa: como el evento no se vuelve a disparar, el estado se
    // pinta acá o el lector saldría del modo inmersivo en cada hoja.
    this.syncFullscreen()
    this.preloadWhenCurrentPageIsVisible()
  }

  disconnect() {
    document.removeEventListener("keydown", this.handleKeydown)
    document.removeEventListener("fullscreenchange", this.syncFullscreen)
    document.removeEventListener("webkitfullscreenchange", this.syncFullscreen)
  }

  handleKeydown(event) {
    // El listener está en document, así que también llegan las teclas del
    // campo "Ir a la página": ahí las flechas son para editar, no para pasar.
    if (event.metaKey || event.ctrlKey || event.altKey || this.isTyping(event.target)) return

    if (event.key === "ArrowLeft" && this.previousUrlValue) {
      Turbo.visit(this.previousUrlValue)
    } else if (event.key === "ArrowRight" && this.nextUrlValue) {
      Turbo.visit(this.nextUrlValue)
    } else if (event.key === "f" || event.key === "F") {
      this.toggleFullscreen()
    } else if (event.key === "Escape" && immersiveFallback) {
      // La pantalla completa real ya la cierra el navegador solo; el modo de
      // respaldo es CSS y tiene que responder a Escape por su cuenta.
      this.leaveFullscreen()
    }
  }

  isTyping(target) {
    return target instanceof HTMLElement &&
      (target.isContentEditable || ["INPUT", "TEXTAREA", "SELECT"].includes(target.tagName))
  }

  toggleFullscreen() {
    if (this.isFullscreen) {
      this.leaveFullscreen()
    } else if (fullscreenAvailable()) {
      // El pedido puede rechazarse (permisos, gesto no reconocido); si pasa,
      // al menos queda la lectura a pantalla completa que el navegador permita.
      requestFullscreen()?.catch(() => this.enterImmersiveFallback())
    } else {
      this.enterImmersiveFallback()
    }
  }

  leaveFullscreen() {
    if (fullscreenElement()) exitFullscreen()
    immersiveFallback = false
    this.syncFullscreen()
  }

  enterImmersiveFallback() {
    immersiveFallback = true
    this.syncFullscreen()
  }

  get isFullscreen() {
    return Boolean(fullscreenElement()) || immersiveFallback
  }

  // Toda la maquetación inmersiva cuelga de este atributo: las variantes
  // group-data-fullscreen:* del partial se encargan del resto.
  syncFullscreen() {
    const active = this.isFullscreen

    this.element.toggleAttribute("data-fullscreen", active)
    if (this.hasToggleTarget) this.toggleTarget.setAttribute("aria-pressed", String(active))
  }

  // Recién cuando la página actual terminó de cargar: si se precargara antes,
  // las descargas de las páginas siguientes competirían por el ancho de banda
  // con la única que el lector está esperando ver ahora.
  preloadWhenCurrentPageIsVisible() {
    const currentPage = this.hasImageTarget ? this.imageTarget : null

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
