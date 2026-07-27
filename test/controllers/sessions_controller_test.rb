require "test_helper"

class SessionsControllerTest < ActionDispatch::IntegrationTest
  test "logs in with correct credentials" do
    post session_path, params: { username: users(:owner).username, password: "password123" }

    assert_redirected_to root_path
    follow_redirect!
    assert_match "Sesión iniciada", response.body
  end

  test "rejects an incorrect password" do
    post session_path, params: { username: users(:owner).username, password: "wrong" }

    assert_response :unprocessable_entity
    assert_match "incorrectos", response.body
  end

  test "rejects an unknown username" do
    post session_path, params: { username: "nadie", password: "password123" }

    assert_response :unprocessable_entity
  end

  test "logs out and clears the session" do
    post session_path, params: { username: users(:owner).username, password: "password123" }

    delete session_path
    assert_redirected_to root_path

    get root_path
    assert_match "Iniciar sesión", response.body
    assert_no_match "Cerrar sesión", response.body
  end
end
