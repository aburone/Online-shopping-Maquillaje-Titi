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

  post '/make_sale/add_credit_note' do
    sale_order = Order.new.create_or_load(Order::SALE)
    o_code = params[:o_code].to_s.strip
    credit_order = Order.new.get_orders_with_type_status_and_code(Order::CREDIT_NOTE, Order::OPEN, o_code)
    DB.transaction do
      Line_payment.new.set_all(o_id: sale_order.o_id, payment_type: Line_payment::CREDIT_NOTE, payment_code: credit_order.o_code, payment_ammount: credit_order.credit_total).save
      credit_order.change_status Order::FINISHED
      credit_order.credits.each { |credit| credit.change_status Cr_status::USED, credit_order.o_id}
    end
    redirect to("/make_sale/checkout")
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

  route :get, :post, "/make_sale/checkout" do
    @order = Order.new.create_or_load(Order::SALE)
    @cart = @order.items_as_cart.all
    @cart_total = @order.cart_total
    @payments = @order.payments
    @payments_total = @order.payments_total
    if @cart.empty?
      flash[:error] = "No poder cobrar una venta vacia"
      redirect to("/make_sale")
    end
    slim :sales_checkout, layout: :layout_sales
  end

  post "/make_sale/finish" do
    begin
      DB.transaction do
        @order = Order.new.create_or_load(Order::SALE)
        @cart_total = @order.cart_total
        @payments_total = @order.payments_total
        items = @order.items
        # Line_payment.new.set_all(o_id: @order.o_id, payment_type: Line_payment::CASH, payment_code: "", payment_ammount: @cart_total - @payments_total).save
        BookRecord.new(b_loc: current_location[:name], o_id: @order.o_id, created_at: Time.now, type: "Venta mostrador", description: "#{items.count}", amount: @cart_total - @payments_total).save
        items.each { |item| item.change_status Item::SOLD, @order.o_id }
        @order.change_status Order::FINISHED
        @cart = @order.items_as_cart.all
      end
    rescue Sequel::ValidationFailed => e
      flash[:error] = e.message
      redirect to("/make_sale")
    end

    headers "Refresh" => "Refresh: 10; /sales"

    html = slim :sales_bill, layout: :layout_print
    kit = PDFKit.new(html, page_size: 'a4', print_media_type: true, debug_javascript: true)
    kit.stylesheets << "public/backend.css"
    kit.stylesheets << "public/print.css"
    pdf_file = kit.to_pdf

    tmp = Tempfile.new(["venta-#{@order.o_code}", "pdf"])
    tmp.binmode
    tmp << pdf_file
    tmp.close
    send_file tmp.path, filename: "venta-#{@order.o_code}.pdf", type: 'application/pdf', disposition: 'inline'
    tmp.unlink
  end

end
