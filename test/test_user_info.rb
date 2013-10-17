require_relative 'prerequisites'

class UserTest < Test::Unit::TestCase

  def setup
    @user = User.new
    @user[:username] = "aburone"
    @user.password="qwe123"
  end


  def test_should_set_session
  end

end
