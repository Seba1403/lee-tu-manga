require "open3"

# Lee tomos .cbr (RAR). No hay una gema Ruby confiable para RAR, así que
# delega en el binario "unrar" (debe estar instalado en el sistema/imagen).
class CbrArchive
  include ComicArchiveCache

  def initialize(path)
    @path = path
  end

  private

  def list_entry_names
    stdout, = run_unrar("lb", "-c-", @path)
    stdout.split("\n")
          .select { |name| ComicPageNaming.image?(name) }
          .sort_by { |name| ComicPageNaming.sort_key(name) }
  end

  def extract_page(name)
    stdout, = run_unrar("p", "-inul", @path, name)
    raise ComicArchiveError, "Página vacía al leer #{name} en #{@path}" if stdout.empty?

    stdout.force_encoding(Encoding::BINARY)
  end

  def run_unrar(*args)
    stdout, status = Open3.capture2("unrar", *args, binmode: true)
    raise ComicArchiveError, "unrar falló (código #{status.exitstatus}) con #{@path}" unless status.success?

    [ stdout, status ]
  rescue Errno::ENOENT
    raise ComicArchiveError, "No se encontró el comando 'unrar'. ¿Está instalado en el sistema?"
  end
end
