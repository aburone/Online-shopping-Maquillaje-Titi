class Backend < AppController
  get '/logistics/?' do
    @orders = Order.new.get_packaging_orders.order(:o_id).reverse
    slim :logistics, layout: :layout_backend, locals: {sec_nav: :nav_logistics}
  end

  get '/logistics/transport/wh_to_wh/select/?' do
    @orders = Order.new.get_orders_in_location_with_type_and_status current_location[:name], Order::WH_TO_WH, Order::OPEN
    slim :wh_to_wh_select, layout: :layout_backend, locals: {sec_nav: :nav_logistics}
  end

  post '/logistics/transport/wh_to_wh/new/?' do
    order = Order.new.create_new Order::WH_TO_WH
    redirect to("/logistics/transport/wh_to_wh/#{order.o_id}/add")
  end

  get '/logistics/transport/warehouse_pos/select/?' do
    @orders = Order.new.get_warehouse_pos__open(current_location[:name])
    slim :warehouse_pos_select, layout: :layout_backend, locals: {sec_nav: :nav_logistics}
  end

  post '/logistics/transport/warehouse_pos/new/?' do
    order = Order.new.create_new Order::WH_TO_POS
    redirect to("/logistics/transport/warehouse_pos/#{order.o_id}/add")
  end

  route :get, :post, ['/logistics/transport/wh_to_wh/:o_id/add/?', '/logistics/transport/warehouse_pos/:o_id/add/?'] do
    case env["sinatra.route"] 
    when "GET /logistics/transport/wh_to_wh/:o_id/add/?", "POST /logistics/transport/wh_to_wh/:o_id/add/?"
      o_type = Order::WH_TO_WH 
      @route = "wh_to_wh"
    when "GET /logistics/transport/warehouse_pos/:o_id/add/?", "POST /logistics/transport/warehouse_pos/:o_id/add/?"
      o_type = Order::WH_TO_POS
      @route = "warehouse_pos"
    end

    @order = Order.new.get_orders_in_location_with_type_status_and_id current_location[:name], o_type, Order::OPEN, params[:o_id].to_i
    if @order.nil?
      flash[:error] = t.order.missing
      redirect to("/logistics/transport/#{@route}/select")
    end

    if params[:i_id]
      @item = Item.new.get_for_transport params[:i_id].to_s.strip, params[:o_id].to_i
      if @item.errors.size > 0
        flash.now[:error] = @item.errors.to_a.flatten.join(": ")
        @product = Product.new
      else 
        begin    
          @order.add_item @item
          @item.change_status Item::MUST_VERIFY, params[:o_id].to_i
          @product = Product[@item.p_id]
        rescue => detail
          flash.now[:error] = detail.message
          @item = Item.new
        end
      end
    end
    @item ||= Item.new
    @items = @order.items
    slim :select_item_to_add_to_transport_order, layout: :layout_backend, locals: {sec_nav: :nav_logistics}
  end

  route :post,  ["/logistics/transport/wh_to_wh/:o_id/:p_id/:i_id/undo/?", "/logistics/transport/warehouse_pos/:o_id/:p_id/:i_id/undo/?"] do
    case env["sinatra.route"] 
    when "POST /logistics/transport/wh_to_wh/:o_id/:p_id/:i_id/undo/?"
      o_type = Order::WH_TO_WH 
      @route = "wh_to_wh"
    when "POST /logistics/transport/warehouse_pos/:o_id/:p_id/:i_id/undo/?"
      o_type = Order::WH_TO_POS
      @route = "warehouse_pos"
    end

    @order = Order.new.get_orders_in_location_with_type_status_and_id current_location[:name], o_type, Order::OPEN, params[:o_id].to_i
    if @order.nil?
      flash[:error] = t.order.missing
      redirect to("/logistics/transport/#{@route}/#{@order.o_id}/add")
    end

    @item = Item.filter(i_id: params[:i_id].to_s.strip, i_status: Item::MUST_VERIFY).first
    if @item.nil?
      flash[:error] = t.item.missing
      redirect to("/logistics/transport/#{@route}/#{@order.o_id}/add")
    end

    flash[:warning] = "Item borrado de la orden. Sigue siendo un item valido para utilizarlo en otra orden"
    @order.remove_item @item
    @item.change_status Item::READY, @order.o_id
    redirect to("/logistics/transport/#{@route}/#{@order.o_id}/add")
  end

  route :post,  ["/logistics/transport/wh_to_wh/:o_id/move/?", "/logistics/transport/warehouse_pos/:o_id/move/?"] do
    case env["sinatra.route"] 
    when "POST /logistics/transport/wh_to_wh/:o_id/move/?"
      o_type = Order::WH_TO_WH 
      @route = "wh_to_wh"
    when "POST /logistics/transport/warehouse_pos/:o_id/move/?"
      o_type = Order::WH_TO_POS
      @route = "warehouse_pos"
    end

    @order = Order.new.get_orders_in_location_with_type_status_and_id current_location[:name], o_type, Order::OPEN, params[:o_id].to_i
    if @order.nil?
      flash[:error] = t.order.missing
      redirect to("/logistics/transport/#{@route}/select") 
    end
    begin
      DB.transaction do
        @order[:o_dst] = params[:o_dst] if Location.new.valid? params[:o_dst]
        @order.save columns: [:o_dst]
        @order.change_status(Order::EN_ROUTE)
        @order.items.each do |item| 
          item.i_loc=params[:o_dst] if Location.new.valid? params[:o_dst]
          item.save
        end
      end
    rescue => e
      flash[:error] = e.message
    end
    redirect to "/logistics/transport/#{@route}/select"
  end
end

