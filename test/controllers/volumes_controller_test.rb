require "test_helper"
require "tmpdir"

class VolumesControllerTest < ActionDispatch::IntegrationTest
  test "guests can read a page without needing a session" do
    with_library_root do |root|
      write_cbz(File.join(root, volumes(:magi_01).file_path))

      get page_volume_path(volumes(:magi_01), number: 0)

      assert_response :success
      assert_equal "image/jpeg", response.media_type
    end
  end

  test "pages are cacheable by the browser so the preloaded ones are reused" do
    with_library_root do |root|
      write_cbz(File.join(root, volumes(:magi_01).file_path))

      get page_volume_path(volumes(:magi_01), number: 0)

      assert_response :success
      assert_includes response.headers["Cache-Control"], "max-age"
      assert_includes response.headers["Cache-Control"], "public"
      assert response.headers["ETag"].present?
    end
  end

  test "the reader preloads the neighbouring pages of the current one" do
    volume = volumes(:magi_02)

    get volume_path(volume, page: 5, mode: "paged")

    assert_response :success
    preloaded = JSON.parse(css_select("[data-reader-preload-urls-value]").first["data-reader-preload-urls-value"])
    assert_includes preloaded, page_volume_path(volume, number: 6)
    assert_includes preloaded, page_volume_path(volume, number: 7)
    assert_includes preloaded, page_volume_path(volume, number: 4)
  end

  test "the last page preloads the first one of the next volume" do
    volume = volumes(:magi_01)

    get volume_path(volume, page: volume.page_count - 1, mode: "paged")

    assert_response :success
    preloaded = JSON.parse(css_select("[data-reader-preload-urls-value]").first["data-reader-preload-urls-value"])
    assert_includes preloaded, page_volume_path(volume.next_volume, number: 0)
  end

  test "returns 404 for a page index that does not exist" do
    with_library_root do |root|
      write_cbz(File.join(root, volumes(:magi_01).file_path))

      get page_volume_path(volumes(:magi_01), number: 999)

      assert_response :not_found
    end
  end

  test "guests can view a volume but progress is not saved" do
    volume = volumes(:magi_02)

    get volume_path(volume, page: 5, mode: "paged")

    assert_response :success
    assert_not volume.reload.reading_progress.present?
  end

  test "the owner's progress is saved while reading" do
    sign_in_owner
    volume = volumes(:magi_02)

    get volume_path(volume, page: 5, mode: "paged")

    assert_response :success
    assert_equal 5, volume.reload.reading_progress.current_page
  end

  test "goto jumps to a 1-indexed page number, overriding page" do
    sign_in_owner
    volume = volumes(:magi_02)

    get volume_path(volume, goto: 46, mode: "paged")

    assert_response :success
    assert_equal 45, volume.reload.reading_progress.current_page
  end

  test "goto is clamped within the volume's page range" do
    sign_in_owner
    volume = volumes(:magi_02)

    get volume_path(volume, goto: 9999, mode: "paged")

    assert_response :success
    assert_equal volume.page_count - 1, volume.reload.reading_progress.current_page
  end

  test "guests patching progress does not persist anything" do
    volume = volumes(:magi_02)

    patch progress_volume_path(volume), params: { page: 7 }

    assert_response :no_content
    assert_not volume.reload.reading_progress.present?
  end

  test "the owner patching progress persists it" do
    sign_in_owner
    volume = volumes(:magi_02)

    patch progress_volume_path(volume), params: { page: 7 }

    assert_response :no_content
    assert_equal 7, volume.reload.reading_progress.current_page
  end

  private

  def sign_in_owner
    post session_path, params: { username: users(:owner).username, password: "password123" }
  end

  def with_library_root
    Dir.mktmpdir do |root|
      original = ENV["MANGA_LIBRARY_PATH"]
      ENV["MANGA_LIBRARY_PATH"] = root
      yield root
    ensure
      ENV["MANGA_LIBRARY_PATH"] = original
    end
  end

  def write_cbz(path, pages: 1)
    FileUtils.mkdir_p(File.dirname(path))
    Zip::File.open(path, create: true) do |zip|
      pages.times { |i| zip.get_output_stream(format("%03d.jpg", i + 1)) { |f| f.write("jpg-bytes-#{i}") } }
    end
  end
end
