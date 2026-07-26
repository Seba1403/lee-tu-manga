class LibraryScanner
  class Error < StandardError; end

  # Vol/Tomo/# seguido de un número (con decimal opcional para extras "1.5").
  # Se prueba en orden: "Tomo 01 (#001-007)" matchea en "Tomo", no en "#001".
  VOLUME_NUMBER_PATTERN = /(?:tomo|vol(?:ume|umen)?|v|\#)\.?\s*(\d+(?:\.\d+)?)/i

  Result = Struct.new(:series_count, :volume_count, :errors, keyword_init: true)

  def self.root_path
    ENV.fetch("MANGA_LIBRARY_PATH", Rails.root.join("..", "mangas").to_s)
  end

  def initialize(root: self.class.root_path)
    @root = Pathname.new(root)
  end

  def scan
    folders = series_folders

    # Si no aparece ninguna carpeta de serie pero ya había series cargadas,
    # lo más probable es que la biblioteca no esté montada (p.ej. un disco
    # externo desconectado) y no que el usuario haya borrado todo. No
    # seguimos: mejor un escaneo fallido y visible que borrar por error todo
    # el progreso de lectura.
    if folders.empty? && Series.exists?
      raise Error, "No se encontró ninguna serie en '#{@root}' pero ya había series en la base de datos. " \
                   "¿Está montada/disponible la carpeta de la biblioteca? No se modificó nada."
    end

    errors = []
    seen_file_paths = []

    folders.each do |folder|
      series = upsert_series(folder)

      cbz_files_in(folder).each do |cbz_path|
        relative_path = cbz_path.relative_path_from(@root).to_s
        seen_file_paths << relative_path

        begin
          upsert_volume(series, cbz_path, relative_path)
        rescue StandardError => e
          Rails.logger.error("[LibraryScanner] #{relative_path}: #{e.message}")
          errors << "#{relative_path}: #{e.message}"
        end
      end
    end

    remove_missing_volumes(seen_file_paths)
    remove_empty_series

    Result.new(series_count: Series.count, volume_count: Volume.count, errors: errors)
  end

  private

  def series_folders
    return [] unless @root.directory?

    @root.children.select(&:directory?).sort_by { |path| path.basename.to_s }
  end

  def cbz_files_in(folder)
    folder.children.select { |path| path.file? && path.extname.downcase == ".cbz" }
          .sort_by { |path| path.basename.to_s }
  end

  def upsert_series(folder)
    relative_path = folder.relative_path_from(@root).to_s
    series = Series.find_or_initialize_by(folder_path: relative_path)
    series.title = folder.basename.to_s
    series.slug = folder.basename.to_s.parameterize
    series.save!
    series
  end

  def upsert_volume(series, cbz_path, relative_path)
    stat = cbz_path.stat
    volume = series.volumes.find_or_initialize_by(file_path: relative_path)

    # No reabrir/reprocesar un .cbz de ~200MB si no cambió desde el último escaneo.
    return if volume.persisted? &&
              volume.file_mtime == stat.mtime &&
              volume.file_size == stat.size

    archive = CbzArchive.new(cbz_path.to_s)
    name_without_extension = cbz_path.basename(".cbz").to_s

    volume.assign_attributes(
      display_name: name_without_extension,
      position: parse_volume_number(name_without_extension),
      file_size: stat.size,
      file_mtime: stat.mtime,
      page_count: archive.page_count,
      cover_page_index: 0
    )
    volume.save!
    volume.reading_progress || volume.create_reading_progress!
    attach_cover(volume, archive)
  end

  def parse_volume_number(name)
    match = VOLUME_NUMBER_PATTERN.match(name)
    match && match[1].to_f
  end

  def attach_cover(volume, archive)
    page = archive.read_page(volume.cover_page_index)
    volume.cover.attach(
      io: StringIO.new(page.data),
      filename: "cover#{extension_for(page.content_type)}",
      content_type: page.content_type
    )
  end

  def extension_for(content_type)
    { "image/jpeg" => ".jpg", "image/png" => ".png", "image/webp" => ".webp", "image/gif" => ".gif" }
      .fetch(content_type, "")
  end

  def remove_missing_volumes(seen_file_paths)
    Volume.where.not(file_path: seen_file_paths).destroy_all
  end

  def remove_empty_series
    Series.left_joins(:volumes).where(volumes: { id: nil }).destroy_all
  end
end
