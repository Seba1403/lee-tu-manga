require "open3"

# Lee tomos .cbr (RAR). No hay una gema Ruby confiable para RAR, así que
# delega en el binario "unrar" (debe estar instalado en el sistema/imagen).
class CbrArchive
  Page = Struct.new(:data, :content_type)

  def initialize(path)
    @path = path
  end

  def page_count
    entry_names.size
  end

  def read_page(index)
    name = entry_names[index]
    raise ComicArchiveError, "No existe la página #{index} en #{@path}" unless name

    stdout, = run_unrar("p", "-inul", @path, name)
    raise ComicArchiveError, "Página vacía al leer #{name} en #{@path}" if stdout.empty?

    Page.new(stdout.force_encoding(Encoding::BINARY), ComicPageNaming.content_type_for(name))
  end

  private

  def entry_names
    @entry_names ||= begin
      stdout, = run_unrar("lb", "-c-", @path)
      stdout.split("\n")
            .select { |name| ComicPageNaming.image?(name) }
            .sort_by { |name| ComicPageNaming.sort_key(name) }
    end
  end

  def run_unrar(*args)
    stdout, status = Open3.capture2("unrar", *args, binmode: true)
    raise ComicArchiveError, "unrar falló (código #{status.exitstatus}) con #{@path}" unless status.success?

    [ stdout, status ]
  rescue Errno::ENOENT
    raise ComicArchiveError, "No se encontró el comando 'unrar'. ¿Está instalado en el sistema?"
  end
end
