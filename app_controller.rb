# coding: utf-8
Encoding.default_internal = 'utf-8'
Encoding.default_external = 'utf-8'
require 'sinatra/base'
require 'sequel'
require 'slim'
require 'pp'
require 'sinatra/r18n'
require "sinatra/multi_route"
require "i18n"
# require "better_errors"



require_relative 'helpers/init'
require_relative 'models/init'

class AppController < Sinatra::Base

  register Sinatra
  register Sinatra::ConfigFile
  config_file '../config.yml'
  $settings = Settings.new '../config.yml'

  register Sinatra::MultiRoute

  register Sinatra::R18n
  R18n.default_places { File.expand_path '../locales', __FILE__ }
  set :root, File.dirname(__FILE__)
  R18n::I18n.default = 'es'
  include R18n::Helpers

  def current_user_id
    session[:user_id]
  end

  def current_user_name
    session[:username]
  end

  def current_location
    session[:current_location]
  end

  configure :production, :development, :test do
    #rack protection
    set :protection, :origin_whitelist => ['http://www.maquillajetiti.com.ar']

    # cache disabled for backend
    before do
      cache_control :no_cache, :no_store, :must_revalidate, :proxy_revalidate
    end

    #slim
    Slim::Engine.set_default_options pretty: true, sort_attrs: false
    set :static, true
    set :public_folder, "#{File.expand_path '../public', __FILE__}"
    set :static_cache_control, [:public, {max_age: 60 * 60 * 24 * 365}]
    views = ['views', 'views/layouts', 'views/pages', 'views/partials', 'views/ajax']
    set :views, views.map{|view| File.expand_path "../#{view}", __FILE__}
    set :template_engine, :slim

  end

  configure :production, :development do
    enable :logging
  end

  configure :production do
    disable :raise_errors
    disable :show_exceptions
    # set :dump_errors, false
  end

  configure :development do
    enable :show_exceptions

    #better errors
    # use BetterErrors::Middleware
    # BetterErrors.application_root = File.expand_path('..', __FILE__)

    # require_relative 'models/stdout_logger'
    require 'sinatra/reloader'
    register Sinatra::Reloader
    enable :reload_templates
    also_reload "models/*.rb"
    also_reload "helpers/*.rb"
    also_reload "sinatra/*.rb"
    also_reload "./*.rb"
    Sinatra::Application.reset!
  end

  configure :test do
  end

  get '/404' do
    slim :not_found, layout: false
  end
  not_found do
    slim :not_found, layout: false
  end
  error do
    pp request.env['sinatra.route']
    pp request.env['REQUEST_PATH']
    pp request.env['sinatra.error']
    @error = request.env['sinatra.error'].message
    slim :error, layout: :layout_bare
  end

  def set_locale
    # session[:locale] = extract_locale_from_accept_language_header || 'es'
    session[:locale] = 'es'
    Thread.current.thread_variable_set(:locale, "es")
  end

  # def extract_locale_from_accept_language_header
  #   begin
  #     request.env['HTTP_ACCEPT_LANGUAGE'].scan(/^[a-z]{2}/).first
  #   rescue
  #     'es'
  #   end
  # end

end

