require "test_helper"

class ReadingProgressTest < ActiveSupport::TestCase
  test "only one reading progress per volume" do
    dupe = ReadingProgress.new(volume: volumes(:magi_01))

    assert_not dupe.valid?
    assert_includes dupe.errors[:volume_id], "has already been taken"
  end

  test "current_page cannot be negative" do
    progress = reading_progresses(:magi_01_progress)
    progress.current_page = -1

    assert_not progress.valid?
  end

  test "update_progress! marks completed on the last page" do
    progress = volumes(:magi_02).progress

    progress.update_progress!(page: 179, total_pages: 180)

    assert progress.completed?
  end

  test "update_progress! marks unread on page zero" do
    progress = reading_progresses(:magi_01_progress)

    progress.update_progress!(page: 0, total_pages: 190)

    assert progress.unread?
  end

  test "update_progress! marks in_progress in between" do
    progress = volumes(:magi_02).progress

    progress.update_progress!(page: 50, total_pages: 180)

    assert progress.in_progress?
  end

  test "update_progress! stamps last_read_at" do
    progress = volumes(:magi_02).progress
    assert_nil progress.last_read_at

    progress.update_progress!(page: 10, total_pages: 180)

    assert progress.last_read_at.present?
  end
end
