require 'sinatra'
require 'sinatra/config_file'
config_file '../../../config.yml'

use Rack::MethodOverride
require 'encrypted_cookie'
require "rack/csrf"
use Rack::Session::EncryptedCookie, secret: settings.cookie_secret, expire_after: settings.session_length
use Rack::Csrf, raise: true, field: 'csrf', key: 'csrf', header: 'X_CSRF_TOKEN' #, :skip => ['POST:/login']

ENV['RACK_ENV'] = 'test'

# require File.join(File.dirname(__FILE__), '..', '..', 'backend.rb')

require 'capybara'
require 'capybara/cucumber'
require 'rspec'

# def app
#   Rack::Builder.new do
#     require_relative '../../app_controller'
#     require_relative '../../backend'
#     require_relative '../../frontend'
#     map('/') { run Frontend }
#     map('/admin') { run Backend }
#   end
# end
# Capybara.app = app

Capybara.app = eval("Rack::Builder.new {( " + File.read(File.dirname(__FILE__) + '/../../config.ru') + "\n )}")


# require 'capybara/poltergeist'
# Capybara.register_driver :poltergeist_debug do |app|
#   Capybara::Poltergeist::Driver.new(app, :inspector => true)
# end

# # Capybara.javascript_driver = :poltergeist
# Capybara.javascript_driver = :poltergeist_debug



class BackendWorld
  include Capybara::DSL
  include RSpec::Expectations
  include RSpec::Matchers
end



World do
  BackendWorld.new
end
