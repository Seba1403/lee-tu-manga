require "test_helper"

class SeriesControllerTest < ActionDispatch::IntegrationTest
  test "guests do not see a continue reading section" do
    get root_path

    assert_response :success
    assert_no_match "Continuar leyendo", response.body
  end

  test "the owner sees a continue reading section with in-progress volumes" do
    sign_in_owner

    get root_path

    assert_response :success
    assert_match "Continuar leyendo", response.body
    assert_match volumes(:magi_01).display_name, response.body
  end

  test "guests see volume links pointing at the start, without any progress indicator" do
    get series_path(series(:magi))

    assert_response :success
    assert_match %r{/volumes/#{volumes(:magi_01).id}\?page=0}, response.body
    assert_no_match "bg-blue-500", response.body
  end

  test "the owner sees volume links pointing at the saved page, with a progress indicator" do
    sign_in_owner

    get series_path(series(:magi))

    assert_response :success
    assert_match %r{/volumes/#{volumes(:magi_01).id}\?page=#{reading_progresses(:magi_01_progress).current_page}}, response.body
    assert_match "bg-blue-500", response.body
  end

  private

  def sign_in_owner
    post session_path, params: { username: users(:owner).username, password: "password123" }
  end
end
