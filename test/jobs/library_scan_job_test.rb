require "test_helper"
require "tmpdir"
require "fileutils"

class LibraryScanJobTest < ActiveJob::TestCase
  test "performs a scan against MANGA_LIBRARY_PATH" do
    Dir.mktmpdir do |root|
      FileUtils.mkdir_p(File.join(root, "One Piece"))
      Zip::File.open(File.join(root, "One Piece", "One Piece Tomo 01.cbz"), create: true) do |zip|
        zip.get_output_stream("001.jpg") { |f| f.write("jpg-bytes") }
      end

      original = ENV["MANGA_LIBRARY_PATH"]
      ENV["MANGA_LIBRARY_PATH"] = root

      perform_enqueued_jobs { LibraryScanJob.perform_later }

      assert Series.exists?(folder_path: "One Piece")
    ensure
      ENV["MANGA_LIBRARY_PATH"] = original
    end
  end
end
