class Sales < AppController

  get '/arrivals/items/?' do
    @pending_items = Item.new.get_in_location_with_status current_location[:name], Item::MUST_VERIFY
    @void_items = Item.new.get_in_location_with_status current_location[:name], Item::VOID
    slim :arrivals_items, layout: :layout_sales, locals: {sec_nav: :nav_sales_arrivals}
  end

  get '/arrivals' do
    @orders = Order.new.get_warehouse_pos__en_route(current_location[:name]).all
    slim :orders_list, layout: :layout_sales, locals: {title: "Ingresos", sec_nav: :nav_sales_arrivals, full_row: true, list_mode: "transport", can_edit: true, edit_link: "/sales/arrivals/o_id"}
  end

  route :get, :post, '/arrivals/:o_id/?' do
    order_verification Order::WH_TO_POS, params
  end

  post '/arrivals/:o_id/:i_id/void' do 
    @item = Item[params[:i_id].to_s.strip]
    begin
      @item.change_status(Item::VOID, params[:o_id].to_i)
    rescue => detail
      flash.now[:error] = detail.message
    end
    slim :void_item_sales, layout: :layout_sales
  end

  post '/arrivals/:o_id/finish' do 
    finish_verification Order::WH_TO_POS, params
  end

  def get_order type, params
    case type 
      when Order::INVENTORY
        @order = Order.new.get_inventory_review_in_location_with_status_and_id(current_location[:name], Order::MUST_VERIFY, params[:o_id].to_i)
      when Order::WH_TO_POS
        @order = Order.new.get_warehouse_pos__en_route_by_id(current_location[:name], params[:o_id].to_i)
    end
    if @order.nil?
      flash[:error] = t.order.missing
      redir = '/inventory/inventory_verification/select' if type == Order::INVENTORY
      redir = '/arrivals' if type == Order::WH_TO_POS
      redirect to(redir)
    end
    @order
  end

  def finish_verification type, params
    @order = get_order type, params

    @pending_items = Item.join(:line_items, [:i_id]).filter(o_id: @order.o_id).filter(i_status: Item::MUST_VERIFY).all
    if @pending_items.count > 0
      flash[:error] = t.production.verifying_packaging.still_pending_items
      redir = "/inventory/inventory_verification/#{@order.o_id}" if type == Order::INVENTORY
      redir = "/arrivals/#{@order.o_id}" if type == Order::WH_TO_POS
      redirect to(redir)
    else
      begin
        DB.transaction do
          @order.change_status Order::VERIFIED
          if type == Order::WH_TO_POS
            @order.items.each do |item| 
              p ""
              p ""
              pp item
              item.change_status(Item::READY, @order.o_id).save if item.i_status == Item::VERIFIED
              pp item
              p ""
              p ""
            end
          end
        end
      rescue => e
        flash[:error] = e.message
      end
      redir = "/inventory/inventory_imputation/select" if type == Order::INVENTORY
      redir = "/arrivals" if type == Order::WH_TO_POS
      redirect to(redir)
    end
  end

  def order_verification type, params
    @order = get_order type, params

    if params[:i_id]
      i_id = params[:i_id].to_s.strip
      @item = Item.new.get_unverified_by_id i_id, @order.o_id

      if @item.errors.count > 0 
        message = @item.errors.to_a.flatten.join(": ")
        ActionsLog.new.set(msg: message, u_id: User.new.current_user_id, l_id: User.new.current_location[:name], lvl: ActionsLog::ERROR, o_id: @order.o_id, p_id: @item.p_id).save
        flash[:error_add_item] = @item.errors
        redir = "/inventory/inventory_verification/#{@order.o_id}" if type == Order::INVENTORY
        redir = "/arrivals/#{@order.o_id}" if type == Order::WH_TO_POS
        redirect to(redir)
      end

      begin    
        @item.change_status Item::VERIFIED, @order.o_id
      rescue => detail
        flash.now[:error] = detail.message
        @item = Item.new
      end
    end

    @item ||= Item.new
    @product = @item.empty? ? Product.new : Product[@item.p_id]
    @pending_items = Item.join(:line_items, [:i_id]).filter(o_id: @order.o_id).filter(i_status: Item::MUST_VERIFY).all
    @verified_items = Item.join(:line_items, [:i_id]).filter(o_id: @order.o_id).filter(i_status: Item::VERIFIED).all
    @void_items = Item.join(:line_items, [:i_id]).filter(o_id: @order.o_id).filter(i_status: Item::VOID).all
    slim :inventory_verify, layout: :layout_backend, locals: {sec_nav: :nav_inventory} if type == Order::INVENTORY
    slim :wh_to_pos_verify, layout: :layout_sales, locals: {sec_nav: :nav_sales_arrivals} if type == Order::WH_TO_POS
  end


end