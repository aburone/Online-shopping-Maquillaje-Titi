# coding: utf-8
class UserTest < Test::Unit::TestCase

  def setup
    @username = "aburone"
    @password = "1234"
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
    assert_equal User.new.valid?( @username, @password ), User.new.get_user( @username )
  end

  def test_should_reject_password
    assert_false User.new.valid?( @username, "INVALID" )
  end

  def create_passwords
    ap BCrypt::Password.create("1234")
  end
end
