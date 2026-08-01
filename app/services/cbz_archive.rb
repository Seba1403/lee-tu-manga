class CbzArchive
  include ComicArchiveCache

  def initialize(path)
    @path = path
  end

  private

  def list_entry_names
    Zip::File.open(@path) do |zip|
      zip.entries
         .reject(&:directory?)
         .map(&:name)
         .select { |name| ComicPageNaming.image?(name) }
         .sort_by { |name| ComicPageNaming.sort_key(name) }
    end
  rescue Zip::Error => e
    raise ComicArchiveError, "No se pudo abrir #{@path}: #{e.message}"
  end

  def extract_page(name)
    Zip::File.open(@path) do |zip|
      zip.get_entry(name).get_input_stream.read
    end
  rescue Zip::Error => e
    raise ComicArchiveError, "No se pudo leer #{@path}: #{e.message}"
  end
end
