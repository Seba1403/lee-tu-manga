require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "requires a username" do
    user = User.new(password: "secret123")

    assert_not user.valid?
    assert_includes user.errors[:username], "can't be blank"
  end

  test "username must be unique" do
    user = User.new(username: users(:owner).username, password: "secret123")

    assert_not user.valid?
    assert_includes user.errors[:username], "has already been taken"
  end

  test "authenticates only with the correct password" do
    user = users(:owner)

    assert user.authenticate("password123")
    assert_not user.authenticate("wrong")
  end
end
