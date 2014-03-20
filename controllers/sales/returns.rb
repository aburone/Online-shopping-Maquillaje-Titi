class Sales < AppController

  route :get, :post, '/returns' do
    @order = Order.new.get_orders_at_location_with_type_status_and_code current_location[:name], Order::SALE, Order::FINISHED, params[:o_code]
    @order ||= Order.new
    if @order.empty? and not params[:o_code].nil?
      flash[:error] = t.errors.invalid_order
      redirect to("/returns")
    end
    @cart = @order.items_as_cart unless @order.empty?
    slim :returns, layout: :layout_sales, locals: {sec_nav: false}
  end

end
