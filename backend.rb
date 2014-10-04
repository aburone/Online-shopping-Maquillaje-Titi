# coding: utf-8
require 'sinatra/flash'
require_relative 'sinatra/auth'
require_relative 'sinatra/my_flash'
require_relative 'sinatra/csrf'

class Backend < AppController
  register Sinatra::ConfigFile
  config_file File.expand_path '../config.yml', __FILE__

  register Sinatra::Auth
  register Sinatra::Flash
  register Sinatra::Csrf
  apply_csrf_protection

  set :name, "Backend"
  helpers ApplicationHelper

  before do
    session.each { |key, value| session.delete(key.to_sym)} if Location.new.stores.include? current_location
    session[:login_path] = "/admin/login"
    session[:root_path] = "../admin"
    session[:layout] = :layout_backend
    set_locale
    unprotected_routes = ["/admin/login", "/admin/logout", "/sales/login", "/sales/logout"]
    protected! unless (request.env["REQUEST_PATH"].nil? or unprotected_routes.include? request.env["REQUEST_PATH"])
  end

  route :get, ['/', '/administration'] do
    protected! # needed by cucumber
    if session[:user_level] > 2
      nav = :nav_administration
      title = t.administration.title
    else
      redirect to ("/production")
    end
    slim :admin, layout: session[:layout], locals: {sec_nav: nav, title: title}
  end

  get '/log' do
    enqueue ActionsLog.new.set(msg: rand, u_id: current_user_id, l_id: current_location[:name], lvl: ActionsLog::INFO)
  end


  Dir["controllers/backend/*.rb"].each { |file| require_relative file }
  Dir["controllers/shared/*.rb"].each { |file| require_relative file }

  run! if __FILE__ == $0

end
