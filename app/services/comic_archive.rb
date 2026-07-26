# Punto de entrada único: devuelve el lector adecuado (zip o rar) según la
# extensión del archivo. El resto de la app (LibraryScanner, VolumesController)
# solo conoce esta interfaz común: #page_count y #read_page(index).
class ComicArchive
  SUPPORTED_EXTENSIONS = %w[.cbz .cbr].freeze

  def self.for(path)
    case File.extname(path).downcase
    when ".cbz" then CbzArchive.new(path)
    when ".cbr" then CbrArchive.new(path)
    else raise ComicArchiveError, "Formato no soportado: #{path}"
    end
  end
end
