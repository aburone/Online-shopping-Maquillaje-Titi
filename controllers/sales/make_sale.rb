class Sales < AppController

  get '/make_sale' do
    @order = Order.new.create_or_load_sale
    @items = @order.items
    @cart = @order.items_as_cart

    @cart_total = 0
    @cart.each { |line_item| @cart_total += line_item[:i_price]*line_item[:qty] }

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
      begin
        BookRecord.new(b_loc: current_location[:name], o_id: @order.o_id, created_at: Time.now, type: "Venta mostrador", description: "#{items.count}", amount: @cart_total).save
      rescue Sequel::ValidationFailed => e
        flash[:error] = e.message
        redirect to("/make_sale")
      end
      items.each { |item| item.change_status Item::SOLD, @order.o_id }
      @order.change_status Order::FINISHED
      @cart = @order.items_as_cart
    end
    slim :sales_bill, layout: :layout_print
  end

end
