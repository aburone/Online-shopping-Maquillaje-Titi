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

  helpers do
    def my_date
      begin
        the_date = "#{params[:year].to_i}/01/01" unless params[:year].nil?
        the_date = "#{params[:year].to_i}/#{params[:month].to_i}" unless params[:month].nil?
        the_date = "#{params[:year].to_i}/#{params[:month].to_i}/#{params[:day].to_i}" unless params[:day].nil?
        date = Date.parse the_date
      rescue => detail
        flash.now[:error] = detail.message == "invalid date" ? "Fecha invalida" : detail.message
        date = Date.today
      end
      date
    end

    def show_day date
      @broad = {machine: (date).strftime("%Y/%m"), human: "Ver por mes"}
      @prev = {machine: (date.prev_day).strftime("%Y/%m/%d"), human: R18n.l(date.prev_day, :full)}
      @curr = R18n.l date, :full
      @next = {machine: (date.next_day).strftime("%Y/%m/%d"), human: R18n.l(date.next_day, :full)}
      @narrow = nil
      @title = "Movimientos de caja de #{R18n.l date, :full}"
      view_records current_location[:name], date.to_s, {days:1}
    end
  end

  get "/books/:year" do
    date = my_date

    @broad = nil
    @prev = {machine: (date.prev_year).strftime("%Y"), human: (date.prev_year).strftime("%Y")}
    @curr = date.strftime("%Y")
    @next = {machine: (date.next_year).strftime("%Y"), human: (date.next_year).strftime("%Y")}
    @narrow = {machine: (date).strftime("%Y/%m"), human: "Ver por mes"}

    @title = "Movimientos de caja de #{params[:year].to_i}"
    view_records current_location[:name], date.to_s, {years:1}
  end
  get "/books/:year/:month" do
    date = my_date

    @broad = {machine: (date).strftime("%Y"), human: "Ver por año"}
    @prev = {machine: (date.prev_month).strftime("%Y/%m"), human: R18n::Locales::Es.new.month_names[date.prev_month.month-1]}
    @curr = R18n::Locales::Es.new.month_names[date.month-1]
    @next = {machine: (date.next_month).strftime("%Y/%m"), human: R18n::Locales::Es.new.month_names[date.next_month.month-1]}
    @narrow = {machine: (date).strftime("%Y/%m/%d"), human: "Ver por dia"}

    @title = "Movimientos de caja de #{R18n::Locales::Es.new.month_names[date.month-1]} de #{params[:year].to_i}"
    view_records current_location[:name], date.to_s, {months:1}
  end
  get "/books/:year/:month/:day" do
    show_day my_date
  end
  get '/books' do
    show_day Date.today
  end

  def view_records location, start_date, interval
    @start_date = Date.parse start_date
    @records = BookRecord.new.from_date_with_interval(location, @start_date.iso8601, interval).all
    
    start = @records.select { |record| record.type == "Caja inicial" }.first
    @starting_cash = start.nil? ? 0 : start[:amount]

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
    @records.reject { |record| record.type == "Caja inicial" }.each{ |record| @finish_cash += record.amount}
    @finish_cash += @starting_cash

    slim :book_records, layout: :layout_sales, locals: {sec_nav: :nav_books}
  end

  get '/books/add' do
    slim :book_records_add, layout: :layout_sales, locals: {sec_nav: :nav_books}
  end
  post '/books/add' do
    record =  BookRecord.new.update_from_hash(params)
    begin
      record.save
    rescue => detail
      flash[:error] = detail.message
    end
    redirect to("/books")
  end



  get '/products' do
    @products = Product.new.get_saleable_at_location(current_location[:name]).all
    slim :products, layout: :layout_sales, locals: {full_row: true, stock_col: true, can_edit: false, sec_nav: :nav_products}
  end

  get '/products/items/?' do
    @items = Item.new.get_in_location_with_status current_location[:name], Item::READY
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
