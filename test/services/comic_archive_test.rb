require "test_helper"

class ComicArchiveTest < ActiveSupport::TestCase
  test "dispatches .cbz to CbzArchive" do
    assert_instance_of CbzArchive, ComicArchive.for("volume.cbz")
  end

  test "dispatches .cbr to CbrArchive" do
    assert_instance_of CbrArchive, ComicArchive.for("volume.cbr")
  end

  test "is case-insensitive on the extension" do
    assert_instance_of CbzArchive, ComicArchive.for("volume.CBZ")
  end

  test "raises ComicArchiveError for unsupported extensions" do
    assert_raises(ComicArchiveError) { ComicArchive.for("volume.pdf") }
  end
end
