# coding: utf-8
require 'sinatra/flash'
require_relative 'sinatra/auth'
require_relative 'sinatra/my_flash'

class Backend < AppController
  register Sinatra::ConfigFile
  config_file File.expand_path '../config.yml', __FILE__

  register Sinatra::Auth
  register Sinatra::Flash
  set :name, "Backend"
  helpers ApplicationHelper

  before do
    session.each { |key, value| session.delete(key.to_sym)} if Location.new.stores.include? current_location
    set_locale
    Thread.current.thread_variable_set(:login_path, "/admin/login")
    Thread.current.thread_variable_set(:root_path, "../admin")
    unprotected_routes = ["/admin/login", "/admin/logout", "/sales/login", "/sales/logout"] 
    protected! unless (request.env["REQUEST_PATH"].nil? or unprotected_routes.include? request.env["REQUEST_PATH"])
    Thread.current.thread_variable_set(:layout, :layout_backend)
  end

  get '/?' do
    protected! # needed by cucumber
    slim :admin, layout: Thread.current.thread_variable_get(:layout)
  end


  Dir["controllers/backend/*.rb"].each { |file| require_relative file }
  Dir["controllers/shared/*.rb"].each { |file| require_relative file }


  get '/logs/?' do
    art_date = Time.now.getlocal("-03:00").to_date.iso8601
    sub = Sequel.date_sub(art_date, {days:1})
    @logs = ActionsLog
              .select(:at, :msg, :lvl, :b_id, :m_id, :i_id, :p_id, :o_id, :u_id, :l_id, :username)
              .join(:users, user_id: :u_id)
              .where{Sequel.expr(:at) >= sub}
              .order(:id)
              .reverse
              .all
    slim :logs, layout: :layout_backend
  end

  run! if __FILE__ == $0

end
