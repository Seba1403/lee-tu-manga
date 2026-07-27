require "test_helper"
require "tmpdir"
require "fileutils"

class LibraryScannerTest < ActiveSupport::TestCase
  test "scans folders into series and volumes, with a cover attached" do
    Dir.mktmpdir do |root|
      build_cbz(File.join(root, "Chainsaw Man", "Chainsaw Man Tomo 01.cbz"), pages: 3)

      # Nota: no se usa assert_difference sobre conteos globales porque este
      # root no incluye las series de los fixtures, así que un scan real
      # también las elimina por "ya no vistas" (comportamiento correcto y
      # cubierto aparte en el test de "removes volumes and series...").
      result = LibraryScanner.new(root: root).scan
      assert_empty result.errors

      volume = Series.find_by!(folder_path: "Chainsaw Man").volumes.sole
      assert_equal "Chainsaw Man Tomo 01", volume.display_name
      assert_equal 3, volume.page_count
      assert_equal 1.0, volume.position
      assert volume.cover.attached?
      assert volume.reading_progress.present?
    end
  end

  test "re-scanning an unchanged file does not reprocess it" do
    Dir.mktmpdir do |root|
      build_cbz(File.join(root, "Chainsaw Man", "Chainsaw Man Tomo 01.cbz"), pages: 3)
      LibraryScanner.new(root: root).scan
      volume = Series.find_by!(folder_path: "Chainsaw Man").volumes.sole
      first_updated_at = volume.updated_at

      LibraryScanner.new(root: root).scan

      assert_equal first_updated_at, volume.reload.updated_at
    end
  end

  test "removes volumes and series whose files disappeared, leaving the rest intact" do
    Dir.mktmpdir do |root|
      build_cbz(File.join(root, "Chainsaw Man", "Chainsaw Man Tomo 01.cbz"))
      build_cbz(File.join(root, "Vinland Saga", "Vinland Saga Tomo 01.cbz"))
      LibraryScanner.new(root: root).scan

      FileUtils.rm_rf(File.join(root, "Chainsaw Man"))

      assert_difference "Series.count", -1 do
        assert_difference "Volume.count", -1 do
          LibraryScanner.new(root: root).scan
        end
      end

      assert_not Series.exists?(folder_path: "Chainsaw Man")
      assert Series.exists?(folder_path: "Vinland Saga")
    end
  end

  test "refuses to wipe existing data when the library root is missing" do
    Dir.mktmpdir do |root|
      build_cbz(File.join(root, "Chainsaw Man", "Chainsaw Man Tomo 01.cbz"))
      LibraryScanner.new(root: root).scan

      assert_no_difference [ "Series.count", "Volume.count" ] do
        assert_raises(LibraryScanner::Error) do
          LibraryScanner.new(root: File.join(root, "does-not-exist")).scan
        end
      end
    end
  end

  test "retries attaching a cover for a volume that was saved without one" do
    Dir.mktmpdir do |root|
      path = File.join(root, "Chainsaw Man", "Chainsaw Man Tomo 01.cbz")
      build_cbz(path, pages: 2)
      stat = File.stat(path)

      series = Series.create!(title: "Chainsaw Man", slug: "chainsaw-man", folder_path: "Chainsaw Man")
      volume = series.volumes.create!(
        display_name: "Chainsaw Man Tomo 01", file_path: "Chainsaw Man/Chainsaw Man Tomo 01.cbz",
        file_size: stat.size, file_mtime: stat.mtime, page_count: 2
      )
      volume.create_reading_progress!
      assert_not volume.cover.attached?

      LibraryScanner.new(root: root).scan

      assert volume.reload.cover.attached?
    end
  end

  private

  def build_cbz(path, pages: 1)
    FileUtils.mkdir_p(File.dirname(path))
    Zip::File.open(path, create: true) do |zip|
      pages.times { |i| zip.get_output_stream(format("%03d.jpg", i + 1)) { |f| f.write("fake-jpg-#{i}") } }
    end
  end
end
