# coding: utf-8
require 'sinatra/flash'
require_relative 'sinatra/auth'
require_relative 'sinatra/my_flash'

class Sales < AppController
  register Sinatra::Auth
  register Sinatra::Flash
  set :name, "Sales"
  helpers ApplicationHelper

  before do
    set_locale
    Thread.current.thread_variable_set(:login_path, "/sales/login")
    Thread.current.thread_variable_set(:root_path, "../sales")
    unprotected_routes = ["/admin/login", "/admin/logout", "/sales/login", "/sales/logout"] 
    protected! unless (unprotected_routes.include? request.env["REQUEST_PATH"])
    Thread.current.thread_variable_set(:layout, :layout_sales)
  end

  get '/?' do
    protected! # needed by cucumber
    slim :sales, layout: :layout_sales
  end


  Dir["controllers/sales/*.rb"].each { |file| require_relative file }
  Dir["controllers/shared/*.rb"].each { |file| require_relative file }


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
    slim :logs, layout: :layout_sales
  end


  get '/products' do
    @products = Product.new.get_saleable_at_location(current_location[:name]).all
    slim :products, layout: :layout_sales, locals: {full_row: true, stock_col: true, can_edit: false, sec_nav: :nav_products}
  end

  get '/products/items/?' do
    @items = Item.new.get_in_location_with_status current_location[:name], Item::READY
    slim :items, layout: :layout_sales, locals: {can_edit: false, sec_nav: :nav_products}
  end



  run! if __FILE__ == $0

end

class Ventas < AppController
  set :name, "Ventas"
  helpers ApplicationHelper

  get '/?' do
    redirect to("../sales/logout")
    halt 401, "must login"
  end

  run! if __FILE__ == $0
end
