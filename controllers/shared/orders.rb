module Orders
  def check params
    raise ArgumentError, R18n::t.errors.invalid_params unless Location.new.valid?(params[:location]) and Order.new.valid_type?(params[:type])
  end

  def locations_n_types
    case current_location[:name]
    when "STORE_1"
      locations_n_types = Location.new.store_1
    else
      locations_n_types = Location.new.warehouses + Location.new.stores
    end
    locations_n_types.map { |location| location[:types] = Order.new.types_at_location location[:name] }
    locations_n_types
  end

  def get_orders
    @locations_n_types = locations_n_types
    unless params.empty?
      check params
      if params[:o_id].nil?
        @orders = Order.new.get_orders_at_location_with_type(params[:location], params[:type]).order(:o_id).reverse.limit(500).all
      elsif params[:o_id].to_i > 0
        @order = Order.new.get_orders_at_location_with_type_and_id(params[:location], params[:type], params[:o_id])
        @items = @order.items
        @bulks = @order.bulks
        if @order.type == Order::SALE
          payments_total = 0 # use Order.payments_total
          BookRecord.where(o_id: @order.o_id).all.each { |payment| payments_total += payment.amount }
          reg_sum = 0
          pro_sum = 0
          @items.each do |item|
            reg_sum =+ item.i_price
            pro_sum =+ item.i_price_pro
          end
          payment_type = payments_total == reg_sum ? "normal" : "profesional"
        end
      end
    end
    if @order && @order.type == Order::CREDIT_NOTE
      credits = @order.credits
      slim :credit_note, layout: Thread.current.thread_variable_get(:layout), locals: {order: @order, credits: credits, sec_nav: :nav_orders, base_url: request.env['REQUEST_PATH']}
    else
      slim :orders, layout: Thread.current.thread_variable_get(:layout),
        locals: {sec_nav: :nav_orders, base_url: request.env['REQUEST_PATH'], title: t.orders.title, payments_total: payments_total, payment_type: payment_type}
    end
  end
end


class Backend < AppController
  include Orders
  get '/orders', "/orders/:location/:type", "/orders/:location/:type/:o_id" do get_orders end
  get "/orders/:o_id" do
    @order = Order.new.get params[:o_id]
    @items = @order.items
    @bulks = @order.bulks
    slim :order, layout: Thread.current.thread_variable_get(:layout), locals: {can_filter: false, title: t.orders.title}
  end
end

class Sales < AppController
  include Orders
  get '/orders', "/orders/:location/:type", "/orders/:location/:type/:o_id" do get_orders end
end
