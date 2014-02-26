ENV["TZ"] = "GMT"
require 'sinatra'
require 'sinatra/config_file'
config_file '../config.yml'

# to allow PUT and DELETE from forms
use Rack::MethodOverride

require 'encrypted_cookie'
require "rack/csrf"
use Rack::Session::EncryptedCookie, secret: settings.cookie_secret, expire_after: settings.session_length

#https://github.com/baldowl/rack_csrf
use Rack::Csrf, raise: true, field: 'csrf', key: 'csrf', header: 'X_CSRF_TOKEN', :skip => ['POST:/admin/products/ajax_update']

use Rack::Deflater

require './app_controller'
require './backend'
require './sales'
require './frontend'
map('/') { run Frontend }
map('/admin') { run Backend }
map('/ventas') { run Ventas }
map('/sales') { run Sales }




