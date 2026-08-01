require "test_helper"
require "tmpdir"

# El entorno de test usa :null_store (ver config/environments/test.rb), que
# nunca memoiza nada, así que estos tests fuerzan un cache_store real para
# poder verificar que list_entry_names/extract_page no se vuelven a invocar
# en un cache hit (que es justo lo que evita reabrir el zip / relanzar unrar
# en cada página).
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

  test "reuses the cached entry list and page bytes across instances of the same file" do
    with_real_cache do
      Dir.mktmpdir do |dir|
        path = File.join(dir, "volume.cbz")
        File.write(path, "irrelevant")

        first = FakeArchive.new(path)
        assert_equal 2, first.page_count
        page = first.read_page(0)
        assert_equal "bytes-for-001.jpg", page.data
        assert_equal "image/jpeg", page.content_type
        assert_equal 1, first.list_calls
        assert_equal 1, first.extract_calls

        second = FakeArchive.new(path)
        repeated = second.read_page(0)

        assert_equal "bytes-for-001.jpg", repeated.data
        assert_equal 0, second.list_calls
        assert_equal 0, second.extract_calls
      end
    end
  end

  test "still extracts an uncached page even when the entry list is already cached" do
    with_real_cache do
      Dir.mktmpdir do |dir|
        path = File.join(dir, "volume.cbz")
        File.write(path, "irrelevant")

        FakeArchive.new(path).read_page(0)

        second = FakeArchive.new(path)
        second.read_page(1)

        assert_equal 0, second.list_calls
        assert_equal 1, second.extract_calls
      end
    end
  end

  test "busts the cache when the file's mtime changes" do
    with_real_cache do
      Dir.mktmpdir do |dir|
        path = File.join(dir, "volume.cbz")
        File.write(path, "irrelevant")
        FakeArchive.new(path).read_page(0)

        File.utime(Time.now, Time.now + 5, path)

        second = FakeArchive.new(path)
        second.read_page(0)

        assert_equal 1, second.list_calls
        assert_equal 1, second.extract_calls
      end
    end
  end

  private

  def with_real_cache
    original = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new
    yield
  ensure
    Rails.cache = original
  end
end
