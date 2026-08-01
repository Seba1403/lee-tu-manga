# Interfaz común de lectura (#page_count, #read_page) para CbzArchive y
# CbrArchive, más la caché del listado de páginas del tomo.
#
# El listado se cachea porque antes se recalculaba en CADA página pedida, solo
# para saber qué nombre de entrada corresponde al índice: en .cbz eso era una
# apertura extra del zip, y en .cbr un proceso "unrar" extra además del de
# extracción (dos spawns por página).
#
# Los bytes de la página NO se cachean, a propósito. Medido sobre un tomo
# realista (200 páginas de ~400 KB), guardarlos en Solid Cache sale más caro de
# lo que ahorra al leer hacia adelante, que es el caso normal: la página nueva
# nunca está en caché, y encima hay que gzipear un JPEG (solid_cache viene con
# compress: true, ~38 ms por página para 0% de ahorro) y escribir ~78 MB por
# tomo contra un tope de caché de 256 MB. Releer una página ya lo resuelve la
# caché del navegador vía ETag/Last-Modified, sin tocar el servidor.
#
# Las clases que lo incluyen solo implementan el "cómo" de cada formato:
# #list_entry_names y #extract_page(name).
module ComicArchiveCache
  Page = Struct.new(:data, :content_type)

  def page_count
    entry_names.size
  end

  def read_page(index)
    name = entry_names[index]
    raise ComicArchiveError, "No existe la página #{index} en #{@path}" unless name

    Page.new(extract_page(name), ComicPageNaming.content_type_for(name))
  end

  private

  # Memoizado también a nivel de instancia (además de Rails.cache) porque
  # LibraryScanner pide page_count y después read_page sobre el mismo objeto,
  # y en el entorno de test el cache_store es :null_store (no guarda nada).
  def entry_names
    @entry_names ||= Rails.cache.fetch(entries_cache_key) { list_entry_names }
  end

  # Incluir el mtime en la clave invalida sola: si el archivo cambia, la
  # próxima lectura usa otra clave y el listado viejo queda inalcanzable
  # (Solid Cache lo termina expulsando por tamaño, no hay que borrarlo a mano).
  def entries_cache_key
    [ "comic_archive", "entries", @path, mtime_i ]
  end

  def mtime_i
    @mtime_i ||= File.mtime(@path).to_i
  rescue Errno::ENOENT
    raise ComicArchiveError, "No se encontró el archivo #{@path}"
  end
end
