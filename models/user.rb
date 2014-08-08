require_relative 'userAuth'
class User < UserAuth

  def to_s
    out = "\n"
    out += "#{self.class} #{sprintf("%x", self.object_id)}:\n"
    out += "\t user_id:  #{@values[:user_id]}\n"
    out += "\t username:  #{@values[:username]}\n"
    out += "\t user_real_name:  #{@values[:user_real_name]}\n"
    out += "\t user_email:  #{@values[:user_email]}\n"
    out += "\t user_real_name:  #{@values[:user_real_name]}\n"
    out += "\t is_active:  #{@values[:is_active]}\n"
    out += "\t session_length:  #{@values[:session_length]}\n"
    out += "\t password:  #{@values[:password]}\n"
    out += "\t level:  #{@values[:level]}\n"
  end

  def curret_user
    Thread.current.thread_variable_get(:user)
  end

  def current_user_id
    current_user_id = Thread.current.thread_variable_get(:user_id)
    current_user_id ||= 1 # system
  end

  def current_user_name
    current_username = Thread.current.thread_variable_get(:username)
    current_username ||= "system"
  end

  def current_location
    current_location = Thread.current.thread_variable_get(:current_location)
    if current_location.nil?
      current_location = {name: "SYSTEM", translation: ConstantsTranslator.new("SYSTEM").t}
    end
    current_location
  end

end

