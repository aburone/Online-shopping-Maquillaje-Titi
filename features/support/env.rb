# IN_BROWSER=true bundle exec cucumber

require 'sinatra'
# require 'sinatra/base'
require 'sinatra/config_file'
require 'sinatra/r18n'


config_file '../../../config.yml'


# use Rack::MethodOverride
# require 'encrypted_cookie'
# require "rack/csrf"
# use Rack::Session::EncryptedCookie, secret: settings.cookie_secret, expire_after: settings.session_length
# use Rack::Csrf, raise: true, field: 'csrf', key: 'csrf', header: 'X_CSRF_TOKEN' #, :skip => ['POST:/login']

register Sinatra::R18n
R18n.default_places { File.expand_path '../locales', __FILE__ }
set :root, File.dirname(__FILE__)
R18n::I18n.default = 'es'
include R18n::Helpers
R18n.set('es', './locales/es.yml')


ENV['RACK_ENV'] = 'test'

# require File.join(File.dirname(__FILE__), '..', '..', 'backend.rb')

require 'rspec'
require 'rspec/expectations'
require 'capybara'
require 'capybara/cucumber'
require 'capybara/poltergeist'


Capybara.app = eval("Rack::Builder.new {( " + File.read(File.dirname(__FILE__) + '/../../config.ru') + "\n )}")


if ENV['IN_BROWSER']
  # On demand: non-headless tests via Selenium/WebDriver
  # To run the scenarios in browser (default: Firefox), use the following command line:
  # IN_BROWSER=true bundle exec cucumber
  # or (to have a pause of 1 second between each step):
  # IN_BROWSER=true PAUSE=1 bundle exec cucumber
  Capybara.default_driver = :selenium
  AfterStep do
    sleep (ENV['PAUSE'] || 0).to_i
  end
else
  # DEFAULT: headless tests with poltergeist/PhantomJS
  Capybara.register_driver :poltergeist do |app|
    Capybara::Poltergeist::Driver.new(
      app,
      window_size: [1280, 1024]#, debug:       true
    )
  end
  Capybara.default_driver    = :poltergeist
  Capybara.javascript_driver = :poltergeist
end


class BackendWorld
  include Capybara::DSL
  include RSpec::Expectations
  include RSpec::Matchers
end



World do
  BackendWorld.new
end
