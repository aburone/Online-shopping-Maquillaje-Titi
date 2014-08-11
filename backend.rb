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
    p "session"
    ap session
    p "params"
    ap params

    session.each { |key, value| session.delete(key.to_sym)} if Location.new.stores.include? current_location
    set_locale
    Thread.current.thread_variable_set(:login_path, "/admin/login")
    Thread.current.thread_variable_set(:root_path, "../admin")
    unprotected_routes = ["/admin/login", "/admin/logout", "/sales/login", "/sales/logout"]
    protected! unless (request.env["REQUEST_PATH"].nil? or unprotected_routes.include? request.env["REQUEST_PATH"])
    Thread.current.thread_variable_set(:layout, :layout_backend)
  end

  route :get, ['/', '/administration'] do
    protected! # needed by cucumber
    if User.new.curret_user.level > 2
      nav = :nav_administration
      title = t.administration.title
    else
      redirect to ("/production")
    end
    slim :admin, layout: Thread.current.thread_variable_get(:layout), locals: {sec_nav: nav, title: title}
  end

  get '/log' do
    enqueue ActionsLog.new.set(msg: rand, u_id: current_user_id, l_id: current_location[:name], lvl: ActionsLog::INFO)
  end


  Dir["controllers/backend/*.rb"].each { |file| require_relative file }
  Dir["controllers/shared/*.rb"].each { |file| require_relative file }

  run! if __FILE__ == $0

end
