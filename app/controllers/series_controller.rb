class SeriesController < ApplicationController
  def index
    @series = Series.includes(volumes: :cover_attachment).order(:title)
    # El progreso de lectura es solo del dueño: sin sesión, no se muestra a nadie más.
    @continue_reading = if owner_signed_in?
      Volume.joins(:reading_progress)
            .merge(ReadingProgress.in_progress)
            .includes(:series, :reading_progress, :cover_attachment)
            .order("reading_progresses.last_read_at DESC")
            .limit(12)
    else
      Volume.none
    end
  end

  def show
    @series = Series.find_by!(slug: params[:slug])
    @volumes = @series.volumes.includes(:reading_progress, :cover_attachment)
  end
end
