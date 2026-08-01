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

const MAX_ZOOM = 5
const DOUBLE_CLICK_ZOOM = 2.5
// Umbral en píxeles para distinguir un arrastre (desplazar la página ampliada)
// de un clic en las zonas laterales, que pasa de hoja.
const DRAG_THRESHOLD = 8

const clamp = (value, min, max) => Math.min(Math.max(value, min), max)

// Navegación con flechas del teclado, pantalla completa, zoom y precarga de
// las páginas vecinas.
export default class extends Controller {
  static targets = ["image", "stage", "toggle"]
  static values = { previousUrl: String, nextUrl: String, preloadUrls: Array }

  connect() {
    this.scale = 1
    this.offsetX = 0
    this.offsetY = 0
    this.pointers = new Map()
    this.pinchDistance = 0
    this.dragDistance = 0

    this.handleKeydown = this.handleKeydown.bind(this)
    this.syncFullscreen = this.syncFullscreen.bind(this)
    this.handleWheel = this.handleWheel.bind(this)
    this.moveGesture = this.moveGesture.bind(this)
    this.endGesture = this.endGesture.bind(this)
    this.suppressClickAfterDrag = this.suppressClickAfterDrag.bind(this)

    document.addEventListener("keydown", this.handleKeydown)
    document.addEventListener("fullscreenchange", this.syncFullscreen)
    document.addEventListener("webkitfullscreenchange", this.syncFullscreen)

    // Estos tres no pasan por data-action porque necesitan opciones que la
    // versión de Stimulus del proyecto no expone: la rueda tiene que poder
    // cancelar el zoom del navegador (passive: false), el clic hay que
    // interceptarlo antes de que el enlace navegue (capture) y el arrastre
    // debe seguir funcionando aunque el puntero se vaya del escenario.
    this.stageTarget.addEventListener("wheel", this.handleWheel, { passive: false })
    this.element.addEventListener("click", this.suppressClickAfterDrag, true)
    window.addEventListener("pointermove", this.moveGesture)
    window.addEventListener("pointerup", this.endGesture)
    window.addEventListener("pointercancel", this.endGesture)

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

    this.stageTarget.removeEventListener("wheel", this.handleWheel)
    this.element.removeEventListener("click", this.suppressClickAfterDrag, true)
    window.removeEventListener("pointermove", this.moveGesture)
    window.removeEventListener("pointerup", this.endGesture)
    window.removeEventListener("pointercancel", this.endGesture)
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
    } else if (event.key === "+" || event.key === "=") {
      this.zoomAt(1.25, ...this.stageCenter())
    } else if (event.key === "-") {
      this.zoomAt(0.8, ...this.stageCenter())
    } else if (event.key === "0") {
      this.resetZoom()
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

  // --- Pantalla completa ---------------------------------------------------

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

    // Entrar o salir cambia el tamaño base de la página, así que un zoom
    // arrastrado desde el otro modo quedaría descuadrado.
    this.resetZoom()
  }

  // --- Zoom ----------------------------------------------------------------
  //
  // La página se ajusta al alto de la pantalla (h-dvh), y el zoom del navegador
  // no puede agrandar eso: al acercar, la ventana mide menos píxeles CSS y la
  // imagen se queda igual mientras el texto sí crece. Por eso el zoom de la
  // página lo hace el lector, con un transform propio.

  toggleZoom(event) {
    if (this.scale > 1) {
      this.resetZoom()
    } else {
      this.zoomAt(DOUBLE_CLICK_ZOOM, event.clientX, event.clientY)
    }
  }

  handleWheel(event) {
    // Fuera de pantalla completa la rueda sigue siendo para desplazar la
    // página; se reserva el zoom para Ctrl/Cmd, que es además lo que emite el
    // gesto de pellizco en los trackpads.
    if (!event.ctrlKey && !event.metaKey && !this.isFullscreen) return

    event.preventDefault()
    this.zoomAt(event.deltaY < 0 ? 1.15 : 1 / 1.15, event.clientX, event.clientY)
  }

  // Amplía manteniendo bajo el cursor el mismo punto de la página: el
  // desplazamiento se corrige en proporción a cuánto creció la imagen.
  zoomAt(factor, clientX, clientY) {
    const next = clamp(this.scale * factor, 1, MAX_ZOOM)
    if (next === this.scale) return

    const ratio = next / this.scale
    const box = this.imageTarget.getBoundingClientRect()
    // El centro sin transformar: getBoundingClientRect() ya devuelve el
    // rectángulo desplazado, así que hay que descontarle el offset actual.
    const centerX = box.left + box.width / 2 - this.offsetX
    const centerY = box.top + box.height / 2 - this.offsetY

    this.offsetX = (clientX - centerX) * (1 - ratio) + ratio * this.offsetX
    this.offsetY = (clientY - centerY) * (1 - ratio) + ratio * this.offsetY
    this.scale = next

    this.clampOffsets()
    this.applyZoom()
  }

  resetZoom() {
    this.scale = 1
    this.offsetX = 0
    this.offsetY = 0
    this.applyZoom()
  }

  applyZoom() {
    const zoomed = this.scale > 1

    this.imageTarget.style.transform = zoomed
      ? `translate(${this.offsetX}px, ${this.offsetY}px) scale(${this.scale})`
      : ""
    this.element.toggleAttribute("data-zoomed", zoomed)
  }

  // Tamaño real de la página dentro del <img>: con object-contain el elemento
  // puede ser bastante más grande que la imagen, y dejar que el paneo entre en
  // esas franjas vacías se siente roto.
  contentSize() {
    const { offsetWidth: width, offsetHeight: height, naturalWidth, naturalHeight } = this.imageTarget
    if (!naturalWidth || !naturalHeight) return { width, height }

    const imageRatio = naturalWidth / naturalHeight

    return imageRatio > width / height
      ? { width, height: width / imageRatio }
      : { width: height * imageRatio, height }
  }

  // No dejar que la página se arrastre más allá de sus bordes.
  clampOffsets() {
    const content = this.contentSize()
    const stage = this.stageTarget.getBoundingClientRect()
    const maxX = Math.max(0, (content.width * this.scale - stage.width) / 2)
    const maxY = Math.max(0, (content.height * this.scale - stage.height) / 2)

    this.offsetX = clamp(this.offsetX, -maxX, maxX)
    this.offsetY = clamp(this.offsetY, -maxY, maxY)
  }

  stageCenter() {
    const stage = this.stageTarget.getBoundingClientRect()
    return [stage.left + stage.width / 2, stage.top + stage.height / 2]
  }

  // --- Gestos de puntero (arrastrar para desplazar, pellizcar para acercar) --

  startGesture(event) {
    if (event.button > 0) return

    this.pointers.set(event.pointerId, { x: event.clientX, y: event.clientY })
    this.dragDistance = 0
    if (this.pointers.size === 2) this.pinchDistance = this.pointerDistance()
  }

  moveGesture(event) {
    const previous = this.pointers.get(event.pointerId)
    if (!previous) return

    const dx = event.clientX - previous.x
    const dy = event.clientY - previous.y
    this.pointers.set(event.pointerId, { x: event.clientX, y: event.clientY })

    if (this.pointers.size >= 2) {
      const distance = this.pointerDistance()
      if (this.pinchDistance > 0) this.zoomAt(distance / this.pinchDistance, ...this.pointerCenter())
      this.pinchDistance = distance
      // Un pellizco nunca debe terminar pasando de página.
      this.dragDistance = Infinity
      return
    }

    if (this.scale === 1) return

    this.dragDistance += Math.abs(dx) + Math.abs(dy)
    this.offsetX += dx
    this.offsetY += dy
    this.clampOffsets()
    this.applyZoom()
  }

  endGesture(event) {
    this.pointers.delete(event.pointerId)
    if (this.pointers.size < 2) this.pinchDistance = 0
  }

  pointerDistance() {
    const [a, b] = Array.from(this.pointers.values())
    return Math.hypot(b.x - a.x, b.y - a.y)
  }

  pointerCenter() {
    const [a, b] = Array.from(this.pointers.values())
    return [(a.x + b.x) / 2, (a.y + b.y) / 2]
  }

  // Se escucha en captura para llegar antes que el enlace: arrastrar la página
  // ampliada pasa por encima de las zonas laterales, y sin esto cada
  // desplazamiento terminaría cambiando de hoja.
  suppressClickAfterDrag(event) {
    if (this.dragDistance <= DRAG_THRESHOLD) return

    event.preventDefault()
    event.stopPropagation()
    this.dragDistance = 0
  }

  // --- Precarga ------------------------------------------------------------

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
