class LibraryScanJob < ApplicationJob
  queue_as :default

  def perform
    result = LibraryScanner.new.scan
    Rails.logger.info(
      "[LibraryScanJob] series=#{result.series_count} volumes=#{result.volume_count} errores=#{result.errors.size}"
    )
    result.errors.each { |error| Rails.logger.warn("[LibraryScanJob] #{error}") }
  end
end
