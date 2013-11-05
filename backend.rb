# coding: utf-8
require 'sinatra/flash'
require_relative 'sinatra/auth'
require_relative 'sinatra/my_flash'

class Backend < AppController
  register Sinatra::Auth
  register Sinatra::Flash
  set :name, "Backend"
  helpers ApplicationHelper

  before do
    set_locale
    Thread.current.thread_variable_set(:login_path, "/admin/login")
    Thread.current.thread_variable_set(:root_path, "../admin")
    unprotected_routes = ["/admin/login", "/admin/logout", "/sales/login", "/sales/logout"] 
    protected! unless (request.env["REQUEST_PATH"].nil? or unprotected_routes.include? request.env["REQUEST_PATH"])
    
  end

  get '/?' do
    protected! # needed by cucumber
    @orders = Order.new.get_orders.order(:o_id).reverse
    slim :admin, layout: :layout_backend
  end

  Dir["controllers/backend/*.rb"].each { |file| require_relative file }


  get '/logs/?' do
    date = Date.today
    art_date = "#{date.iso8601} 03:00"
    add = Sequel.date_add(art_date, {days:1})

    @logs = ActionsLog
              .select(:at, :msg, :lvl, :b_id, :m_id, :i_id, :p_id, :o_id, :u_id, :l_id, :username)
              .join(:users, user_id: :u_id)
              .where{Sequel.expr(:at) >= art_date}.where{Sequel.expr(:at) < add}
              .order(:id)
              .reverse
              .all
    slim :logs, layout: :layout_backend
  end

  run! if __FILE__ == $0

end
