class Backend < AppController
  get '/logistics/?' do
    @orders = Order.new.get_packaging_orders.order(:o_id).reverse
    slim :logistics, layout: :layout_backend, locals: {sec_nav: :nav_production}
  end

  get '/logistics/transport/inter_warehouse?' do
    slim :logistics, layout: :layout_backend, locals: {sec_nav: :nav_production}
  end

  get '/logistics/transport/warehouse_pos?' do
    slim :logistics, layout: :layout_backend, locals: {sec_nav: :nav_production}
  end

  get '/logistics/transport/warehouse_pos/select/?' do
    @orders = Order.new.get_warehouse_pos__open(current_location[:name])
    slim :warehouse_pos_select, layout: :layout_backend, locals: {sec_nav: :nav_production}
  end

  post '/logistics/transport/warehouse_pos/new/?' do
    order = Order.new.create_new Order::WH_TO_POS
    redirect to("/logistics/transport/warehouse_pos/#{order.o_id}/add")
  end

  route :get, :post, '/logistics/transport/warehouse_pos/:o_id/add/?' do
    @order = Order.new.get_warehouse_pos__open_by_id(params[:o_id].to_i, current_location[:name]).first
    if @order.nil?
      flash[:error] = t.order.missing
      redirect to('/logistics/transport/warehouse_pos/select')
    end

    if params[:i_id]
      @item = Item.filter(i_id: params[:i_id].to_s.strip, i_status: Item::READY).first
      if @item.nil?
        flash.now[:error] = t.item.invalid
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
    slim :select_item_to_add_to_transport_order, layout: :layout_backend, locals: {sec_nav: :nav_production}
  end

  post '/logistics/transport/warehouse_pos/:o_id/:i_id/cancel/?' do
    @order = Order.new.get_warehouse_pos__open_by_id(params[:o_id].to_i, current_location[:name]).first
    if @order.nil?
      flash[:error] = t.order.missing
      redirect to("/logistics/transport/warehouse_pos/#{@order.o_id}/add")
    end

    @item = Item.filter(i_id: params[:i_id].to_s.strip, i_status: Item::MUST_VERIFY).first
    if @item.nil?
      flash[:error] = t.item.missing
      redirect to("/logistics/transport/warehouse_pos/#{@order.o_id}/add")
    end

    flash[:warning] = "Item borrado de la orden. Sigue siendo un item valido para utilizarlo en otra orden"
    @order.remove_item @item
    @item.change_status Item::READY, @order.o_id
    redirect to("/logistics/transport/warehouse_pos/#{@order.o_id}/add")
  end
end

