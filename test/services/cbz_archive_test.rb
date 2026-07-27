require "test_helper"
require "tmpdir"

class CbzArchiveTest < ActiveSupport::TestCase
  test "lists pages in natural numeric order and skips non-images" do
    Dir.mktmpdir do |dir|
      path = File.join(dir, "volume.cbz")
      Zip::File.open(path, create: true) do |zip|
        zip.get_output_stream("002.png") { |f| f.write("png-bytes") }
        zip.get_output_stream("001.jpg") { |f| f.write("jpg-bytes") }
        zip.get_output_stream("notes.txt") { |f| f.write("not an image") }
      end

      archive = CbzArchive.new(path)
      assert_equal 2, archive.page_count

      first = archive.read_page(0)
      assert_equal "jpg-bytes", first.data
      assert_equal "image/jpeg", first.content_type

      second = archive.read_page(1)
      assert_equal "png-bytes", second.data
      assert_equal "image/png", second.content_type
    end
  end

  test "raises ComicArchiveError for an out-of-range page" do
    Dir.mktmpdir do |dir|
      path = File.join(dir, "volume.cbz")
      Zip::File.open(path, create: true) do |zip|
        zip.get_output_stream("001.jpg") { |f| f.write("jpg-bytes") }
      end

      assert_raises(ComicArchiveError) { CbzArchive.new(path).read_page(5) }
    end
  end

  test "raises ComicArchiveError for a missing file" do
    assert_raises(ComicArchiveError) { CbzArchive.new("/nonexistent.cbz").read_page(0) }
  end
end
