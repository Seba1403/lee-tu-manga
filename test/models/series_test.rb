require "test_helper"

class SeriesTest < ActiveSupport::TestCase
  test "fixture is valid" do
    assert series(:magi).valid?
  end

  test "requires title, slug and folder_path" do
    series = Series.new

    assert_not series.valid?
    assert_includes series.errors[:title], "can't be blank"
    assert_includes series.errors[:slug], "can't be blank"
    assert_includes series.errors[:folder_path], "can't be blank"
  end

  test "slug must be unique" do
    dupe = Series.new(title: "Otro", slug: series(:magi).slug, folder_path: "Otro")

    assert_not dupe.valid?
    assert_includes dupe.errors[:slug], "has already been taken"
  end

  test "folder_path must be unique" do
    dupe = Series.new(title: "Otro", slug: "otro", folder_path: series(:magi).folder_path)

    assert_not dupe.valid?
    assert_includes dupe.errors[:folder_path], "has already been taken"
  end

  test "to_param uses the slug" do
    assert_equal series(:magi).slug, series(:magi).to_param
  end

  test "destroying a series destroys its volumes" do
    assert_difference -> { Volume.count }, -series(:magi).volumes.count do
      series(:magi).destroy
    end
  end
end
