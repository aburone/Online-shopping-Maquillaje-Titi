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
  end

  get '/?' do
    protected! # needed by cucumber
    slim :sales, layout: :layout_sales
  end

  Dir["controllers/sales/*.rb"].each { |file| require_relative file }


  get '/books' do
    @starting_cash = BookRecord.new.get_last_cash_audit(current_location[:name])[:amount]
    @records = BookRecord.new.from_last_audit current_location[:name]

    @sales_total = 0
    @records.select { |record| record.type == "Venta mostrador" }.each { |record| @sales_total += record.amount }

    @commissions = 0
    @records.select { |record| record.type == "Comisiones" }.each{ |record| @commissions += record.amount}



    @expenses = 0
    @records.select { |record| record.type == "Otros gastos" }.each { |record| @expenses += record.amount }

    @downpayments = 0
    @records.select { |record| record.type == "Pago a proveedor" }.each { |record| @downpayments += record.amount }


    surplus = 0
    @records.select { |record| record.type == "Sobrante de caja" }.each{ |record| surplus += record.amount}
    deficit = 0
    @records.select { |record| record.type == "Faltante de caja" }.each{ |record| deficit += record.amount}
    @diferences =  surplus + deficit

    @finish_cash = 0
    @records.each { |record| @finish_cash += record.amount }

    slim :book_records, layout: :layout_sales, locals: {sec_nav: :nav_books}
  end
  get '/books/add' do
    slim :book_records_add, layout: :layout_sales, locals: {sec_nav: :nav_books}
  end
  post '/books/add' do

    record =  BookRecord.new.update_from_hash(params)
    pp record
    begin
      record.save
    rescue => detail
      flash[:error] = detail.message
    end
    # flash[:error] = record.errors
    # slim :book_records_add, layout: :layout_sales, locals: {sec_nav: :nav_books}
    redirect to("/books")
  end



  get '/products' do
    @products = Product.new.get_saleable_at_location(current_location[:name]).all
    slim :products, layout: :layout_sales, locals: {can_edit: false, sec_nav: :nav_products}
  end

  get '/products/items/?' do
    @items = Item.new.get_list_at_location current_location[:name]
    slim :items, layout: :layout_sales, locals: {can_edit: false, sec_nav: :nav_products}
  end

  get '/make_sale' do 
    @order = Order.new.create_or_load_sale
    @items = @order.items
    @cart = @order.items_as_cart
    slim :sales_make_sale, layout: :layout_sales, locals: {sec_nav: :nav_sales_actions}
  end

  post '/make_sale/add_item' do 
    i_id = params[:i_id].to_s.strip
    order = Order.new.create_or_load_sale
    item = Item.new.get_for_sale i_id, order.o_id
    if item.errors.count > 0
      message = item.errors.to_a.flatten.join(": ")
      ActionsLog.new.set(msg: message, u_id: User.new.current_user_id, l_id: User.new.current_location[:name], lvl: ActionsLog::ERROR, o_id: order.o_id, p_id: item.p_id, i_id: item.i_id).save
      flash[:error] = item.errors
    else
      added_msg = order.add_item item
      changed_msg = item.change_status Item::ON_CART, order.o_id
      flash[:notice] = [added_msg, changed_msg]
    end
    redirect to('/make_sale')
  end

  post "/sales/make_sale/cancel" do
    order = Order.new.create_or_load_sale
    order.cancel_sale
    flash[:notice] = "Orden cancelada"
    redirect to('/')
  end

  post "/sales/make_sale/pro" do
    message = Order.new.create_or_load_sale.recalculate_as(params[:type].to_sym)
    flash[:notice] = message
    redirect to('/make_sale')
  end

  post "/sales/make_sale/checkout" do
    @order = Order.new.create_or_load_sale
    @cart = @order.items_as_cart
    @cart_total = @order.cart_total 
    slim :sales_checkout, layout: :layout_sales
  end

  post "/sales/make_sale/finish" do
    DB.transaction do
      @order = Order.new.create_or_load_sale
      items = @order.items
      @cart_total = @order.cart_total 
      BookRecord.new(b_loc: current_location[:name], o_id: @order.o_id, created_at: Time.now, type: "Venta mostrador", description: "#{items.count}", amount: @cart_total).save
      items.each { |item| item.change_status Item::SOLD, @order.o_id }
      @order.change_status Order::FINISHED
      @cart = @order.items_as_cart
    end
    slim :sales_bill, layout: :layout_print
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
