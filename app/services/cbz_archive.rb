class CbzArchive
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

    Zip::File.open(@path) do |zip|
      data = zip.get_entry(name).get_input_stream.read
      Page.new(data, ComicPageNaming.content_type_for(name))
    end
  rescue Zip::Error => e
    raise ComicArchiveError, "No se pudo leer #{@path}: #{e.message}"
  end

  private

  def entry_names
    @entry_names ||= Zip::File.open(@path) do |zip|
      zip.entries
         .reject(&:directory?)
         .map(&:name)
         .select { |name| ComicPageNaming.image?(name) }
         .sort_by { |name| ComicPageNaming.sort_key(name) }
    end
  rescue Zip::Error => e
    raise ComicArchiveError, "No se pudo abrir #{@path}: #{e.message}"
  end
end
