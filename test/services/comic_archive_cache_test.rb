require "test_helper"
require "tmpdir"

# El entorno de test usa :null_store (ver config/environments/test.rb), que no
# guarda nada, así que estos tests instalan un cache real para poder verificar
# que el listado de páginas del tomo se calcula una sola vez y no en cada
# página pedida (que es lo que evitaba el doble unrar en .cbr).
class ComicArchiveCacheTest < ActiveSupport::TestCase
  class FakeArchive
    include ComicArchiveCache

    attr_reader :list_calls, :extract_calls

    def initialize(path)
      @path = path
      @list_calls = 0
      @extract_calls = 0
    end

    private

    def list_entry_names
      @list_calls += 1
      [ "001.jpg", "002.jpg" ]
    end

    def extract_page(name)
      @extract_calls += 1
      "bytes-for-#{name}"
    end
  end

  test "reuses the cached page list across instances of the same file" do
    with_real_cache do
      with_archive_file do |path|
        first = FakeArchive.new(path)
        assert_equal 2, first.page_count
        page = first.read_page(0)
        assert_equal "bytes-for-001.jpg", page.data
        assert_equal "image/jpeg", page.content_type
        assert_equal 1, first.list_calls

        second = FakeArchive.new(path)
        second.read_page(1)

        assert_equal 0, second.list_calls
      end
    end
  end

  test "lists the pages only once even when reading several pages" do
    with_real_cache do
      with_archive_file do |path|
        archive = FakeArchive.new(path)
        archive.read_page(0)
        archive.read_page(1)
        archive.read_page(0)

        assert_equal 1, archive.list_calls
      end
    end
  end

  # Los bytes se extraen siempre: cachearlos salía más caro que extraerlos
  # (ver el comentario en ComicArchiveCache), y releer una página la resuelve
  # la caché del navegador sin llegar al servidor.
  test "extracts the page bytes on every read" do
    with_real_cache do
      with_archive_file do |path|
        FakeArchive.new(path).read_page(0)

        second = FakeArchive.new(path)
        second.read_page(0)

        assert_equal 1, second.extract_calls
      end
    end
  end

  test "recalculates the page list when the file's mtime changes" do
    with_real_cache do
      with_archive_file do |path|
        FakeArchive.new(path).read_page(0)

        File.utime(Time.now, Time.now + 5, path)

        second = FakeArchive.new(path)
        second.read_page(0)

        assert_equal 1, second.list_calls
      end
    end
  end

  test "raises ComicArchiveError when the file is gone" do
    with_real_cache do
      assert_raises(ComicArchiveError) { FakeArchive.new("/nonexistent.cbz").read_page(0) }
    end
  end

  test "raises ComicArchiveError for an out-of-range page" do
    with_real_cache do
      with_archive_file do |path|
        assert_raises(ComicArchiveError) { FakeArchive.new(path).read_page(99) }
      end
    end
  end

  private

  def with_archive_file
    Dir.mktmpdir do |dir|
      path = File.join(dir, "volume.cbz")
      File.write(path, "el contenido no importa: FakeArchive no lo abre")
      yield path
    end
  end

  def with_real_cache
    original = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new
    yield
  ensure
    Rails.cache = original
  end
end
