require_relative 'userAuth'
class User < UserAuth

  def print
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

  def empty?
    return user_id.nil? ? true : false
  end

  def current_user_id
    current_user_id = State.current_user.user_id unless State.current_user.nil?
    current_user_id ||= 1 # system
  end

  def current_user_name
    current_username = State.current_user.username unless State.current_user.nil?
    current_username ||= "system"
  end

  def current_location
    current_location =  State.current_location unless State.current_location.nil?
    if current_location.nil?
      current_location = {name: "SYSTEM", translation: ConstantsTranslator.new("SYSTEM").t}
    end
    current_location
  end

end
