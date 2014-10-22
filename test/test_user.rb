# coding: utf-8
require_relative 'prerequisites'
class UserTest < Test::Unit::TestCase

  def setup
    @active_username = "aburone"
    @active_password = "1234"

    @inactive_username = "veronica"
    @inactive_password = "qwe123"
  end

  def how_to
    # https://github.com/codahale/bcrypt-ruby

    my_password = BCrypt::Password.create("my password")
    #=> "$2a$10$vI8aWBnW3fID.ZQ4/zo1G.q1lRps.9cGLcZEiGDMVr5yUP1KUOYTa"
    my_password.version              #=> "2a"
    my_password.cost                 #=> 10
    my_password == "my password"     #=> true
    my_password == "not my password" #=> false

    my_password = BCrypt::Password.new("$2a$10$l1MLSp6gZvxX263Z9cxZnOHuaB5XdwaNtmL3819w/U/mov5uRKysu")
    my_password == "qwe123"     #=> true
    my_password == "not my password" #=> false
  end

  def test_should_diferentiate_unicode_usernames
    u = User.new.get_user "aburone"
    u2 = User.new.get_user "áburone"
    assert_not_equal( u, u2)
  end

  def test_should_validate_good_password
    assert_equal User.new.valid?( @active_username, @active_password ), User.new.get_user( @active_username )
  end

  def test_should_reject_inactive_user
    assert_false User.new.valid? @inactive_username, @inactive_password
  end

  def test_should_reject_password
    assert_false User.new.valid?( @active_username, "INVALID" )
  end

  def create_passwords
    pass =  BCrypt::Password.create("****", {cost: 16})
  end
end
