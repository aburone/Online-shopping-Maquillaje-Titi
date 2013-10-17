class UserAuth < Sequel::Model(:users)
  require "bcrypt"
  BCrypt::Engine.cost = 8

  def get_by_id user_id
    User[user_id.to_i]
  end

  def get_user username
    User.where(Sequel.like(:username, username)).first
  end

  def valid? username, password
    user = get_user username
    if user && (valid_pass? user, password )
      return user
    else
      return false
    end
  end

  private
    def valid_pass? user, password
      stored = BCrypt::Password.new( user[:password] )
      stored == password
      true
    end

end
