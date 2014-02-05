class Backend < AppController
  get '/transport/departures/wh_to_wh/select/?' do
    @orders = Order.new.get_orders_at_location_with_type_and_status current_location[:name], Order::WH_TO_WH, Order::OPEN
    slim :wh_to_wh_select, layout: :layout_backend, locals: {sec_nav: :nav_logistics}
  end

  post '/transport/departures/wh_to_wh/new/?' do
    order = Order.new.create_new Order::WH_TO_WH
    redirect to("/transport/departures/wh_to_wh/#{order.o_id}/add")
  end

  get '/transport/departures/wh_to_pos/select/?' do
    @orders = Order.new.get_wh_to_pos__open(current_location[:name])
    slim :wh_to_pos_select, layout: :layout_backend, locals: {sec_nav: :nav_logistics}
  end

  post '/transport/departures/wh_to_pos/new/?' do
    order = Order.new.create_new Order::WH_TO_POS
    redirect to("/transport/departures/wh_to_pos/#{order.o_id}/add")
  end


  route :get, :post, ['/transport/departures/wh_to_wh/:o_id/add/?', '/transport/departures/wh_to_pos/:o_id/add/?'] do
    o_type = o_type_from_route
    @order = Order.new.get_orders_at_location_with_type_status_and_id current_location[:name], o_type, Order::OPEN, params[:o_id].to_i
    redirect_if_nil_order @order, params[:o_id].to_i, "#{@route}/select"
    @route = "/transport/departures/#{@order.type.downcase}"

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
            flash.now[:notice] = t.order.item_added @product.p_name, @order.o_id
          rescue => detail
            flash.now[:error] = detail.message
            @item = Item.new
          end
        end
      elsif id.size == 13 && o_type == Order::WH_TO_WH
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
        flash.now[:error] = t.errors.invalid_label
      end
    end
    @item ||= Item.new
    @bulk ||= Bulk.new
    @items = @order.items
    @bulks = @order.bulks
    @module = "/admin"
    slim :select_item_to_add_to_transport_order, layout: :layout_backend, locals: {sec_nav: :nav_logistics}
  end


  route :post,  ["/transport/departures/wh_to_wh/:o_id/move/?", "/transport/departures/wh_to_pos/:o_id/move/?"] do
    o_type = o_type_from_route

    order = get_orders_at_location_with_type_status_and_id_or_redirect current_location[:name], o_type_from_route, Order::OPEN, params[:o_id].to_i, "/transport/departures/#{o_type_from_route}/select"
    begin
      DB.transaction do
        order[:o_dst] = params[:o_dst] if Location.new.valid? params[:o_dst]
        order.save columns: [:o_dst]
        order.change_status(Order::EN_ROUTE)
        order.items.each do |item| 
          item.i_loc=params[:o_dst] if Location.new.valid? params[:o_dst]
          item.save
        end
        order.bulks.each do |bulk| 
          bulk.b_loc=params[:o_dst] if Location.new.valid? params[:o_dst]
          bulk.save
        end
      end
    rescue => e
      flash[:error] = e.message
    end
    redirect to "/transport/departures/#{order.type.downcase}/select"
  end
end

