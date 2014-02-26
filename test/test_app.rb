require_relative 'prerequisites'
require_relative '../app_controller.rb'
require_relative '../backend.rb'

class AppTest < Test::Unit::TestCase
  include Rack::Test::Methods
  def app
    Backend
  end

  def test_should_see_login_form
    get '/'
    assert_equal 401, last_response.status, "Not trying to authenticate"
    assert_match /login_form/, last_response.body, "No login form"
  end

  def test_should_try_to_authenticate
    get '/', {}, 'rack.session' => get_sess
    assert_match /Administración/, last_response.body, "Wrong place"
    kill_session


    # assert last_response.ok?, "not ok"
    # pp last_request.path_info
    # p last_request.methods
    # p last_response.methods
    # p last_response.body
    # pp last_response.errors
    # pp last_response.headers
    # p last_response.status
    # assert_equal 'Welcome to my page!', last_response.body, "incorrect body"
  end

  def test_materials_id_invalid
    get '/materials/yadda', {}, 'rack.session' => get_sess
    assert_equal 302, last_response.status, "Error in get '/materials/yadda'"
    kill_session
  end


  def get_sess
    {:locale=>"es",
     :username=>"aburone",
     :user_real_name=>"",
     :user_id=>2,
     :current_location=>{:name=>"WAREHOUSE_1", :translation=>"Deposito 1", :level=>2}}
  end
end
