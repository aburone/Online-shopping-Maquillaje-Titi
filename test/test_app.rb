# require_relative 'prerequisites'
# require_relative '../app_controller.rb'
# require_relative '../backend.rb'

# class AppTest < Test::Unit::TestCase
#   include Rack::Test::Methods
#   def app
#     Backend
#   end

#   def test_should_try_to_authenticate
#     get '/'
#     # assert_equal 401, last_response.status, "Not trying to authenticate"
#     # pp last_response.methods
#     # pp last_response.errors
#     # pp last_response.headers
#     # pp last_response.status
#     # assert_equal 'Welcome to my page!', last_response.body, "incorrect body"
#   end

#   def test_should_authenticate
#     # digest_authorize "admin", "a"
#     get '/'
#     pp last_response.status
#   end
# end
