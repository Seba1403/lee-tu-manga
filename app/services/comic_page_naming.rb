# Reglas compartidas por CbzArchive y CbrArchive: qué entradas son páginas de
# imagen, su content-type, y el orden natural (por número líder en el
# nombre) en vez de orden alfabético puro.
module ComicPageNaming
  IMAGE_CONTENT_TYPES = {
    ".jpg" => "image/jpeg",
    ".jpeg" => "image/jpeg",
    ".png" => "image/png",
    ".webp" => "image/webp",
    ".gif" => "image/gif"
  }.freeze

  module_function

  def image?(name)
    IMAGE_CONTENT_TYPES.key?(File.extname(name).downcase)
  end

  def content_type_for(name)
    IMAGE_CONTENT_TYPES.fetch(File.extname(name).downcase, "application/octet-stream")
  end

  def sort_key(name)
    basename = File.basename(name)
    digits = basename[/\d+/]
    [ digits ? digits.to_i : Float::INFINITY, basename ]
  end
end
