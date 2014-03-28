class Sales < AppController


  route :get, :post, '/returns' do
    preexistent_return_order = Order.filter(type: Order::RETURN, o_status: Order::OPEN, u_id: current_user_id, o_loc: current_location[:name]).first
    if preexistent_return_order.nil?
      @sale_order = get_sale_order_by_code_or_redirect params[:o_code], "/returns"
      @sale_cart = @sale_order.items_as_cart unless @sale_order.empty?
      slim :returns, layout: :layout_sales, locals: {sec_nav: false}
    else
      sale_order = Order[SalesToReturn.filter(return: preexistent_return_order.o_id).first[:sale]]
      flash[:warning] = "Ya hay una orden de devolucion abierta con anterioridad"
      redirect to( "/returns/#{sale_order.o_code}")
    end
  end


  route :get, :post, '/returns/:o_code' do
    @sale_order = get_sale_order_by_code_or_redirect params[:o_code], "/returns"
    @sale_cart = @sale_order.items_as_cart unless @sale_order.empty?
    @return_order = Order.new.create_or_load_return @sale_order.o_id
    unless params[:i_id].nil?
      @item = Item.new.get_for_return params[:i_id], @return_order.o_id
      @return_order.add_item @item unless @item.empty?
      @item.change_status(Item::RETURNING, @return_order.o_id).save
    end
    @return_cart = @return_order.items_as_cart_detailed unless @return_order.empty?
    flash.now[:error] = @return_order.errors if @return_order.errors.count > 0
    flash.now[:error] = @item.errors if !params[:i_id].nil? && @item.errors.count > 0
    slim :returns, layout: :layout_sales, locals: {sec_nav: false}
  end


  route :post, '/returns/:o_id/cancel' do
    order = Order.new.get_orders_at_location_with_type_status_and_id current_location[:name], Order::RETURN, Order::OPEN, params[:o_id].to_i
    redirect_if_nil_order order, params[:o_id].to_i, "/returns"
    if order.cancel_return
      flash[:notice] = "Orden borrada. Todos los items volvieron al estado Vendido"
    else
      flash[:error] = "Fallo el borrado de la orden"
    end
    redirect to ("/returns")
  end


  route :post, '/returns/:o_id/finish' do
    order = Order.new.get_orders_at_location_with_type_status_and_id current_location[:name], Order::RETURN, Order::OPEN, params[:o_id].to_i
    redirect_if_nil_order order, params[:o_id].to_i, "/returns"

    if order.finish_return
      credit_order = Order.new.create Order::CREDIT_NOTE
      Line_payment.new.set_all(o_id: credit_order.o_id, payment_type: "NC Emitida", payment_code: credit_order.o_code, payment_ammount: order.cart_total * -1).save
      flash[:notice] = t.return.finished
      redirect to ("/returns/get_pdf/#{credit_order.o_code}")
    else
      flash[:error] = t.return.failed
      redirect to ("/returns")
    end
  end


  route :get, '/returns/get_pdf/:o_code' do
    o_code = Order.new.remove_dash_from_code params[:o_code].to_s.strip
    order = Order.new.get_orders_at_location_with_type_status_and_code current_location[:name], Order::CREDIT_NOTE, Order::OPEN, o_code
    slim :print_credit_note, layout: :layout_sales, locals: {credit_total: Utils::money_format(order.credit_total, 2), o_code: order.o_code_with_dash}
  end


  route :put, '/returns/get_pdf/:o_code' do
    order = Order.new.get_orders_at_location_with_type_status_and_code current_location[:name], Order::CREDIT_NOTE, Order::OPEN, params[:o_code].to_s.strip

    # require 'tempfile'
    # barcodes = Bulk.new.get_as_csv current_location[:name]
    # tmp = Tempfile.new(["barcodes", ".csv"])
    # tmp << barcodes
    # tmp.close
    # send_file tmp.path, filename: 'bulks.csv', type: 'octet-stream', disposition: 'attachment'
    # tmp.unlink

    # redirect to ("/returns")
    ""
  end


  def get_sale_order_by_code_or_redirect o_code, redir
    order = Order.new.get_orders_at_location_with_type_status_and_code current_location[:name], Order::SALE, Order::FINISHED, o_code
    if order.empty? && !params[:o_code].nil?
      flash[:error] = order.errors.to_a.flatten.join(": ")
      redirect to(redir)
    end
    order
  end


end
