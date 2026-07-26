class CbzArchive
  class Error < StandardError; end

  Page = Struct.new(:data, :content_type)

  IMAGE_CONTENT_TYPES = {
    ".jpg" => "image/jpeg",
    ".jpeg" => "image/jpeg",
    ".png" => "image/png",
    ".webp" => "image/webp",
    ".gif" => "image/gif"
  }.freeze

  def initialize(path)
    @path = path
  end

  def page_count
    entry_names.size
  end

  def read_page(index)
    name = entry_names[index]
    raise Error, "No existe la página #{index} en #{@path}" unless name

    Zip::File.open(@path) do |zip|
      data = zip.get_entry(name).get_input_stream.read
      Page.new(data, content_type_for(name))
    end
  rescue Zip::Error => e
    raise Error, "No se pudo leer #{@path}: #{e.message}"
  end

  private

  def entry_names
    @entry_names ||= Zip::File.open(@path) do |zip|
      zip.entries
         .reject(&:directory?)
         .map(&:name)
         .select { |name| IMAGE_CONTENT_TYPES.key?(File.extname(name).downcase) }
         .sort_by { |name| sort_key(name) }
    end
  rescue Zip::Error => e
    raise Error, "No se pudo abrir #{@path}: #{e.message}"
  end

  # Ordena por el número líder en el nombre de archivo (p.ej. "003 pagina.jpg")
  # en vez de orden alfabético puro, para no depender de que todos los
  # scanlations rellenen con ceros a la izquierda.
  def sort_key(name)
    basename = File.basename(name)
    digits = basename[/\d+/]
    [ digits ? digits.to_i : Float::INFINITY, basename ]
  end

  def content_type_for(name)
    IMAGE_CONTENT_TYPES.fetch(File.extname(name).downcase, "application/octet-stream")
  end
end
