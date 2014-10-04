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
    session.each { |key, value| session.delete(key.to_sym)} if Location.new.warehouses.include? current_location # logout if logged in from warehouse
    set_locale
    session[:login_path] = "/sales/login"
    session[:root_path] = "../sales"
    session[:layout] = :layout_sales
    unprotected_routes = ["/admin/login", "/admin/logout", "/sales/login", "/sales/logout"]
    protected! unless (unprotected_routes.include? request.env["REQUEST_PATH"])
  end

  get '/?' do
    protected! # needed by cucumber
    slim :sales, layout: :layout_sales
  end


  Dir["controllers/sales/*.rb"].each { |file| require_relative file }
  Dir["controllers/shared/*.rb"].each { |file| require_relative file }


  get '/products' do
    @products = Product.new.get_saleable_at_location(current_location[:name]).order(:c_name, :p_name).all
    slim :products, layout: :layout_sales, locals: {full_row: true, stock_col: true, can_edit: false, can_filter: true, sec_nav: :nav_products, title: t.products.title}
  end

  get '/products/items/?' do
    @items = Item.new.get_items_at_location_with_status current_location[:name], Item::READY
    slim :items, layout: :layout_sales, locals: {can_edit: false, can_filter: true, sec_nav: :nav_products, title: "Items disponibles"}
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
