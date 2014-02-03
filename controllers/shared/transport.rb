class Backend < AppController
  get '/logistics/transport/wh_to_wh/select/?' do
    @orders = Order.new.get_orders_at_location_with_type_and_status current_location[:name], Order::WH_TO_WH, Order::OPEN
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
      @route = "wh_to_wh"
    when "GET /logistics/transport/warehouse_pos/:o_id/add/?", "POST /logistics/transport/warehouse_pos/:o_id/add/?"
      @route = "warehouse_pos"
    end
    o_type = o_type_from_route

    @order = Order.new.get_orders_at_location_with_type_status_and_id current_location[:name], o_type, Order::OPEN, params[:o_id].to_i
    redirect_if_nil_order @order, params[:o_id].to_i, "/logistics/transport/#{@route}/select"

    if params[:i_id].nil?
    elsif params[:i_id]
      id = params[:i_id].to_s.strip
      if id.size == 12
        @item = Item.new.get_for_transport id.to_s.strip, params[:o_id].to_i
        if @item.errors.size > 0
          flash.now[:error] = @item.errors.to_a.flatten.join(": ")
          @product = Product.new
        else 
          begin    
            @order.add_item @item
            @item.change_status Item::MUST_VERIFY, params[:o_id].to_i
            @product = Product[@item.p_id]
            flash.now[:notice] = t.order.item_added
          rescue => detail
            flash.now[:error] = detail.message
            @item = Item.new
          end
        end
      elsif id.size == 13
        @bulk = Bulk.new.get_for_transport id.to_s.strip, params[:o_id].to_i
        if @bulk.errors.size > 0
          flash.now[:error] = @bulk.errors.to_a.flatten.join(": ")
          @material = Material.new
        else 
          begin    
            @order.add_bulk @bulk
            @bulk.change_status Bulk::MUST_VERIFY, params[:o_id].to_i
            @material = Material[@bulk.m_id]
            flash.now[:notice] = t.order.bulk_added
          rescue => detail
            flash.now[:error] = detail.message
            @bulk = Bulk.new
          end
        end
      else
        flash.now[:error] = "ID incorrecto"
      end
    end
    @item ||= Item.new
    @bulk ||= Bulk.new
    @items = @order.items
    @bulks = @order.bulks
    p ""
    pp @bulks
    slim :select_item_to_add_to_transport_order, layout: :layout_backend, locals: {sec_nav: :nav_logistics}
  end

  route :post,  ["/logistics/transport/wh_to_wh/:o_id/:p_id/:i_id/undo/?", "/logistics/transport/warehouse_pos/:o_id/:p_id/:i_id/undo/?"] do
    case env["sinatra.route"] 
    when "POST /logistics/transport/wh_to_wh/:o_id/:p_id/:i_id/undo/?"
      route = "wh_to_wh"
    when "POST /logistics/transport/warehouse_pos/:o_id/:p_id/:i_id/undo/?"
      route = "warehouse_pos"
    end
    o_type = o_type_from_route


    order = Order.new.get_orders_at_location_with_type_status_and_id current_location[:name], o_type, Order::OPEN, params[:o_id].to_i
    redirect_if_nil_order order, params[:o_id].to_i, "/logistics/transport/#{route}/#{order.o_id}/add"

    id = params[:i_id].to_s.strip
    if id.size == 12
      item = Item.filter(i_id: id, i_status: Item::MUST_VERIFY).first
      redirect_if_nil_item item, id, "/logistics/transport/#{route}/#{order.o_id}/add"
      flash[:warning] = "Item borrado de la orden. Sigue siendo un item valido para utilizarlo en otra orden"
      order.remove_item item
      item.change_status Item::READY, order.o_id
    elsif id.size == 13 && order.type == Order::WH_TO_WH 
      bulk = Bulk.filter(b_id: id, b_status: Bulk::MUST_VERIFY).first
      redirect_if_nil_bulk bulk, id, "/logistics/transport/#{route}/#{order.o_id}/add"
      flash[:warning] = "Bulk borrado de la orden. Sigue siendo un bulk valido para utilizarlo en otra orden"
      order.remove_bulk bulk
      bulk.change_status Bulk::NEW, order.o_id
    end
    redirect to("/logistics/transport/#{route}/#{order.o_id}/add")
  end

  route :post,  ["/logistics/transport/wh_to_wh/:o_id/move/?", "/logistics/transport/warehouse_pos/:o_id/move/?"] do
    case env["sinatra.route"] 
    when "POST /logistics/transport/wh_to_wh/:o_id/move/?"
      route = "wh_to_wh"
    when "POST /logistics/transport/warehouse_pos/:o_id/move/?"
      route = "warehouse_pos"
    end
    o_type = o_type_from_route

    order = Order.new.get_orders_at_location_with_type_status_and_id current_location[:name], o_type, Order::OPEN, params[:o_id].to_i
    if order.nil?
      flash[:error] = t.order.missing
      redirect to("/logistics/transport/#{route}/select") 
    end
    begin
      DB.transaction do
        order[:o_dst] = params[:o_dst] if Location.new.valid? params[:o_dst]
        order.save columns: [:o_dst]
        order.change_status(Order::EN_ROUTE)
        order.items.each do |item| 
          item.i_loc=params[:o_dst] if Location.new.valid? params[:o_dst]
          item.save
        end
      end
    rescue => e
      flash[:error] = e.message
    end
    redirect to "/logistics/transport/#{route}/select"
  end
end

