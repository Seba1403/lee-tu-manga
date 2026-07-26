class VolumesController < ApplicationController
  READER_MODES = %w[paged scroll].freeze

  before_action :set_volume

  def show
    @page_number = params[:page].to_i.clamp(0, [ @volume.page_count - 1, 0 ].max)
    @mode = resolve_mode

    # En modo cascada el progreso se actualiza vía JS mientras se hace scroll (ver #progress).
    @volume.progress.update_progress!(page: @page_number, total_pages: @volume.page_count) if @mode == "paged"
  end

  def page
    number = params[:number].to_i
    fresh_when(etag: [ @volume.file_path, @volume.file_mtime, number ], last_modified: @volume.file_mtime, public: true)
    return if performed?

    page = ComicArchive.for(@volume.absolute_path).read_page(number)
    send_data page.data, type: page.content_type, disposition: "inline"
  rescue ComicArchiveError
    head :not_found
  end

  def progress
    page = params[:page].to_i.clamp(0, [ @volume.page_count - 1, 0 ].max)
    @volume.progress.update_progress!(page: page, total_pages: @volume.page_count)
    head :no_content
  end

  private

  def set_volume
    @volume = Volume.includes(:series).find(params[:id])
  end

  def resolve_mode
    requested = params[:mode].presence
    mode = READER_MODES.include?(requested) ? requested : cookies[:reader_mode]
    mode = READER_MODES.include?(mode) ? mode : "paged"
    cookies.permanent[:reader_mode] = mode if requested
    mode
  end
end
