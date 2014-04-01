class Sales < AppController

  get '/make_sale' do
    @order = Order.new.create_or_load(Order::SALE)
    @items = @order.items
    @cart = @order.items_as_cart
    @cart_total = 0
    @cart.each { |line_item| @cart_total += line_item[:i_price]*line_item[:qty] }
    slim :make_sale, layout: :layout_sales, locals: {sec_nav: :nav_sales_actions}
  end

  post '/make_sale/add_item' do
    i_id = params[:i_id].to_s.strip
    order = Order.new.create_or_load(Order::SALE)
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

  post "/make_sale/cancel" do
    order = Order.new.create_or_load(Order::SALE)
    order.cancel_sale
    flash[:notice] = "Orden cancelada"
    redirect to('/')
  end

  post "/make_sale/pro" do
    message = Order.new.create_or_load(Order::SALE).recalculate_as(params[:type].to_sym)
    flash[:notice] = message
    redirect to('/make_sale')
  end

  post "/make_sale/checkout" do
    @order = Order.new.create_or_load(Order::SALE)
    @cart = @order.items_as_cart
    @cart_total = @order.cart_total
    slim :sales_checkout, layout: :layout_sales
  end

  post "/make_sale/finish" do
    begin
      DB.transaction do
        @order = Order.new.create_or_load(Order::SALE)
        items = @order.items
        @cart_total = @order.cart_total
        Line_payment.new.set_all(o_id: @order.o_id, payment_type: Line_payment::TYPE[:CASH], payment_code: "", payment_ammount: @cart_total).save
        BookRecord.new(b_loc: current_location[:name], o_id: @order.o_id, created_at: Time.now, type: "Venta mostrador", description: "#{items.count}", amount: @cart_total).save
        items.each { |item| item.change_status Item::SOLD, @order.o_id }
        @order.change_status Order::FINISHED
        @cart = @order.items_as_cart
      end
    rescue Sequel::ValidationFailed => e
      flash[:error] = e.message
      redirect to("/make_sale")
    end

    response.headers['Content-Type'] = "application/pdf"
    response.headers['Content-Disposition'] = "attachment; filename=venta-#{@order.o_code}.pdf"
    html = slim :sales_bill, layout: :layout_print
    kit = PDFKit.new(html, :page_size => 'a4')
    kit.stylesheets << "public/backend.css"
    kit.stylesheets << "public/print.css"
    kit.to_pdf
  end

end
