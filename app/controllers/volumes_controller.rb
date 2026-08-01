class VolumesController < ApplicationController
  READER_MODES = %w[paged scroll].freeze

  before_action :set_volume

  def show
    @page_number = resolve_page_number
    @mode = resolve_mode

    # El progreso solo se guarda para el dueño logueado; una visita sin sesión
    # puede leer normal pero no pisa el progreso compartido.
    # En modo cascada el progreso se actualiza vía JS mientras se hace scroll (ver #progress).
    @volume.progress.update_progress!(page: @page_number, total_pages: @volume.page_count) if @mode == "paged" && owner_signed_in?
  end

  def page
    number = params[:number].to_i
    # Sin un max-age explícito el navegador decide por heurística si puede
    # reutilizar lo que ya bajó, y ahí se pierde la precarga: volvería a pedir
    # la página (aunque sea un 304) justo al pasar de hoja. Una hora alcanza de
    # sobra para una sesión de lectura; si el archivo se reemplaza, el ETag
    # incluye el mtime y la próxima revalidación lo detecta igual.
    expires_in 1.hour, public: true
    fresh_when(etag: [ @volume.file_path, @volume.file_mtime, number ], last_modified: @volume.file_mtime, public: true)
    return if performed?

    page = ComicArchive.for(@volume.absolute_path).read_page(number)
    send_data page.data, type: page.content_type, disposition: "inline"
  rescue ComicArchiveError
    head :not_found
  end

  def progress
    page = params[:page].to_i.clamp(0, [ @volume.page_count - 1, 0 ].max)
    @volume.progress.update_progress!(page: page, total_pages: @volume.page_count) if owner_signed_in?
    head :no_content
  end

  private

  def set_volume
    @volume = Volume.includes(:series).find(params[:id])
  end

  # "goto" es el número de página humano (1-indexado, el que se ve en pantalla)
  # que manda el formulario de "ir a la página"; "page" sigue siendo el
  # parámetro interno 0-indexado que ya usan todos los links existentes.
  def resolve_page_number
    page = params[:goto].present? ? params[:goto].to_i - 1 : params[:page].to_i
    page.clamp(0, [ @volume.page_count - 1, 0 ].max)
  end

  def resolve_mode
    requested = params[:mode].presence
    mode = READER_MODES.include?(requested) ? requested : cookies[:reader_mode]
    mode = READER_MODES.include?(mode) ? mode : "paged"
    cookies.permanent[:reader_mode] = mode if requested
    mode
  end
end
