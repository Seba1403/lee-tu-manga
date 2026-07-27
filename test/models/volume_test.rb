require "test_helper"

class VolumeTest < ActiveSupport::TestCase
  test "fixture is valid" do
    assert volumes(:magi_01).valid?
  end

  test "requires display_name, file_path, file_size, file_mtime and page_count" do
    volume = Volume.new(series: series(:magi))

    assert_not volume.valid?
    assert_includes volume.errors[:display_name], "can't be blank"
    assert_includes volume.errors[:file_path], "can't be blank"
    assert_includes volume.errors[:file_size], "can't be blank"
    assert_includes volume.errors[:file_mtime], "can't be blank"
    assert_includes volume.errors[:page_count], "can't be blank"
  end

  test "file_path must be unique" do
    dupe = Volume.new(
      series: series(:tokyo_ghoul), display_name: "Otro", file_path: volumes(:magi_01).file_path,
      file_size: 1, file_mtime: Time.current, page_count: 1
    )

    assert_not dupe.valid?
    assert_includes dupe.errors[:file_path], "has already been taken"
  end

  test "#progress returns the existing reading progress" do
    assert_equal reading_progresses(:magi_01_progress), volumes(:magi_01).progress
  end

  test "#progress builds a new unsaved progress when there is none yet" do
    progress = volumes(:magi_02).progress

    assert_not progress.persisted?
    assert_equal volumes(:magi_02), progress.volume
  end

  test "#absolute_path joins the library root with the relative file_path" do
    expected = File.join(LibraryScanner.root_path, volumes(:magi_01).file_path)

    assert_equal expected, volumes(:magi_01).absolute_path
  end

  test "#next_volume and #previous_volume follow series order" do
    assert_equal volumes(:magi_02), volumes(:magi_01).next_volume
    assert_nil volumes(:magi_01).previous_volume

    assert_equal volumes(:magi_01), volumes(:magi_02).previous_volume
    assert_nil volumes(:magi_02).next_volume
  end
end
