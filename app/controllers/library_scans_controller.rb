class LibraryScansController < ApplicationController
  before_action :require_owner!

  def create
    LibraryScanJob.perform_later
    redirect_back fallback_location: root_path, notice: "Escaneo de biblioteca encolado."
  end
end
