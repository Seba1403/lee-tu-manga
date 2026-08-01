# Cachea (vía Rails.cache / Solid Cache) el listado de páginas y los bytes ya
# extraídos de un tomo, para que abrir y parsear el archivo (zip o unrar)
# ocurra una sola vez por versión del archivo (mtime) en vez de en cada
# página. Antes, CbzArchive reabría el zip dos veces por página (listado +
# lectura) y CbrArchive lanzaba dos procesos "unrar" por página (uno para
# listar entradas, otro para extraer); con esto, en caliente, ninguno de los
# dos vuelve a tocar el archivo.
#
# Las subclases (CbzArchive, CbrArchive) solo implementan cómo listar
# entradas (#list_entry_names) y extraer una página (#extract_page); este
# módulo se encarga de cachear ambos resultados y de exponer la interfaz
# común (#page_count, #read_page).
module ComicArchiveCache
  Page = Struct.new(:data, :content_type)

  def page_count
    entry_names.size
  end

  def read_page(index)
    name = entry_names[index]
    raise ComicArchiveError, "No existe la página #{index} en #{@path}" unless name

    data = Rails.cache.fetch(page_cache_key(index)) { extract_page(name) }
    Page.new(data, ComicPageNaming.content_type_for(name))
  end

  private

  # Memoizado también a nivel de instancia (además del Rails.cache) porque
  # LibraryScanner llama a page_count y luego a read_page sobre el mismo
  # objeto, y en test el cache_store es :null_store (no memoiza nada).
  def entry_names
    @entry_names ||= Rails.cache.fetch(entries_cache_key) { list_entry_names }
  end

  def entries_cache_key
    [ "comic_archive", "entries", @path, mtime_i ]
  end

  def page_cache_key(index)
    [ "comic_archive", "page", @path, mtime_i, index ]
  end

  # Cachear por mtime invalida solo: si el archivo cambia (re-descarga,
  # reemplazo), la próxima lectura usa una key distinta y listados/páginas
  # viejos quedan simplemente inalcanzables (Solid Cache los expulsa por
  # tamaño con el tiempo, no hace falta borrarlos a mano).
  def mtime_i
    @mtime_i ||= File.mtime(@path).to_i
  rescue Errno::ENOENT
    raise ComicArchiveError, "No se encontró el archivo #{@path}"
  end
end
