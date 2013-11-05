class Backend < AppController

  get '/inventory' do
    @orders = Order.new.get_inventory_review_in_location current_location[:name]
    @message = "Carga inicial de inventario. Material peligroso. Manipular con cuidado."
    slim :admin, layout: :layout_backend, locals: {sec_nav: :nav_inventory}
  end

  get '/inventory/items/?' do
    @items = Item.new.get_list_at_location(current_location[:name]).all
    slim :items, layout: :layout_backend, locals: {sec_nav: :nav_inventory}
  end

  get '/inventory/inventory_review/select' do
    @orders = Order.new.get_inventory_review.filter(o_status: Order::OPEN)
    slim :inventory_review_select, layout: :layout_backend, locals: {sec_nav: :nav_inventory}
  end

  post '/inventory/inventory_review/new' do
    order = Order.new.create_new Order::INVENTORY
    redirect to("/inventory/inventory_review/#{order.o_id}")
  end

  post '/inventory/inventory_review/:o_id/cancel' do
    order = Order.new.get_inventory_review_in_location_with_status_and_id(current_location[:name], Order::OPEN, params[:o_id].to_i)
    if order.nil?
      flash[:error] = t.order.missing
    else
      order.cancel
      flash[:warning] = t.order.cancelled(params[:o_id].to_i)
    end
    redirect to("/inventory/inventory_review/select")
  end

  post '/inventory/inventory_verification/:o_id/cancel' do
    order = Order.new.get_inventory_review_in_location_with_status_and_id(current_location[:name], Order::MUST_VERIFY, params[:o_id].to_i)
    if order.nil?
      flash[:error] = t.order.missing
    else
      order.cancel
      flash[:warning] = t.order.cancelled(params[:o_id].to_i)
    end
    redirect to("/inventory/inventory_verification/select")
  end

  post '/inventory/inventory_review/:o_id/finish_load' do
    order = Order.new.get_inventory_review_in_location_with_status_and_id(current_location[:name], Order::OPEN, params[:o_id].to_i)
    if order.nil?
      flash[:error] = t.order.missing
    else
      order.finish_load
      flash[:notice] = t.order.ready_for_verification
    end
    redirect to("/inventory/inventory_verification/select")
  end

  route :get, :post, '/inventory/inventory_review/:o_id' do
    inventory_review params
  end
  route :get, :post, '/inventory/inventory_review/:o_id/:p_id' do
    inventory_review params
  end

  post '/inventory/inventory_review/:o_id/:p_id/:i_id/undo' do
    order = Order.new.get_inventory_review_in_location_with_status_and_id(current_location[:name], Order::OPEN, params[:o_id].to_i)
    product = Product[params[:p_id].to_i]
    item = Item[params[:i_id].to_s.strip]
    order.remove_item item
    product.remove_item item
    if order.errors.count > 0 or product.errors.count > 0
      fash[:error] = [order.errors, product.errors]
    else
      flash[:warning] = "Etiqueta dissociada del producto y la orden. Podes asignarla a otro producto."
    end
    redirect to("/inventory/inventory_review/#{order.o_id}")
  end

  def inventory_review params
    @order = Order.new.get_inventory_review_in_location_with_status_and_id(current_location[:name], Order::OPEN, params[:o_id].to_i)
    if @order.nil?
      flash[:error] = t.order.missing
      redirect to('/inventory/inventory_review/select')
    end
    @product = []
    @products = []
    if params[:p_id]
      @product = Product[params[:p_id].to_i]
      if params[:i_id]
        i_id = params[:i_id].to_s.strip
        item =  Label.new.get_printed_by_id i_id, @order.o_id
        if item.errors.count > 0 
          message = item.errors.to_a.flatten.join(": ")
          ActionsLog.new.set(msg: message, u_id: User.new.current_user_id, l_id: User.new.current_location[:name], lvl: ActionsLog::ERROR, o_id: @order.o_id, p_id: @product.p_id).save
          flash[:error_add_item] = item.errors
          redirect to("/inventory/inventory_review/#{@order.o_id}/#{@product.p_id}")
        end

        assigned_msg = @product.add_item item, @order.o_id
        if @product.errors.count > 0 
          flash[:error_add_item] = @product.errors
          redirect to("/inventory/inventory_review/#{@order.o_id}/#{@product.p_id}")
        else
          @item = Item[i_id]
          added_msg = @order.add_item @item
          if @order.errors.count > 0 
            flash[:error_add_item_to_order] = @order.errors
            redirect to("/inventory/inventory_review/#{@order.o_id}/#{@product.p_id}")
          end
          @item.change_status(Item::MUST_VERIFY, @order.o_id)
        end
        flash[:notice] = [assigned_msg, added_msg]
      end
    else
      @products = Product.new.get_list.all
    end

    @item ||= Item.new
    @items = @order.items

    slim :inventory_add, layout: :layout_backend, locals: {sec_nav: :nav_inventory}
  end




  get '/inventory/inventory_verification/select' do
    @orders = Order.new.get_inventory_verification
    slim :inventory_verification_select, layout: :layout_backend, locals: {sec_nav: :nav_inventory}
  end
  route :get, :post, '/inventory/inventory_verification/:o_id' do
    inventory_verification params
  end

  post '/inventory/inventory_verification/:o_id/:i_id/void' do 
    @order = Order[params[:o_id].to_i]
    @item = Item[params[:i_id].to_s.strip]
    @order.remove_item(@item)
    begin
      @item.change_status(Item::VOID, params[:o_id].to_i)
    rescue => detail
      flash.now[:error] = detail.message
    end
    slim :void_item, layout: :layout_backend_void_item
  end

  post '/inventory/inventory_verification/:o_id/finish' do 
    @order = Order[params[:o_id].to_i]
    @pending_items = Item.join(:line_items, [:i_id]).filter(o_id: @order.o_id).filter(i_status: Item::MUST_VERIFY).all
    if @pending_items.count > 0
      flash[:error] = t.production.verifying_packaging.still_pending_items
      redirect to "/inventory/inventory_verification//#{@order.o_id}"
    else
      @order.change_status Order::VERIFIED
      redirect to('/inventory/inventory_imputation/select')
    end
  end

  post '/inventory/inventory_verification/:o_id/:p_id/:i_id/undo' do
    order = Order.new.get_inventory_review_in_location_with_id(current_location[:name], params[:o_id].to_i)
    puts order
    product = Product[params[:p_id].to_i]
    puts product
    item = Item[params[:i_id].to_s.strip]
    puts item
    order.remove_item item
    product.remove_item item
    if order.errors.count > 0 or product.errors.count > 0
      fash[:error] = [order.errors, product.errors]
    else
      flash[:warning] = "Etiqueta dissociada del producto y la orden. Podes asignarla a otro producto."
    end
    redirect to("/inventory/inventory_verification/#{order.o_id}")
  end

  def inventory_verification params
    @order = Order.new.get_inventory_review_in_location_with_status_and_id(current_location[:name], Order::MUST_VERIFY, params[:o_id].to_i)
    if @order.nil?
      flash[:error] = t.order.missing
      redirect to('/inventory/inventory_verification/select')
    end

    if params[:i_id]
      i_id = params[:i_id].to_s.strip
      @item = Item.new.get_unverified_by_id i_id, @order.o_id

      if @item.errors.count > 0 
        message = @item.errors.to_a.flatten.join(": ")
        ActionsLog.new.set(msg: message, u_id: User.new.current_user_id, l_id: User.new.current_location[:name], lvl: ActionsLog::ERROR, o_id: @order.o_id, p_id: @item.p_id).save
        flash[:error_add_item] = @item.errors
        redirect to("/inventory/inventory_verification/#{@order.o_id}")
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
    slim :inventory_verify, layout: :layout_backend, locals: {sec_nav: :nav_inventory}
  end

  get '/inventory/inventory_imputation/select' do
    @orders = Order.new.get_inventory_imputation
    slim :inventory_imputation_select, layout: :layout_backend, locals: {sec_nav: :nav_inventory}
  end

  get '/inventory/inventory_imputation/:o_id' do
    @order = Order.new.get_inventory_imputation.filter(o_id: params[:o_id].to_i).first
    @items = @order.items
    slim :inventory_imputation_confirm, layout: :layout_backend, locals: {sec_nav: :nav_inventory}
  end

  post '/inventory/inventory_imputation/:o_id/finish' do
    order = Order.new.get_inventory_imputation.filter(o_id: params[:o_id].to_i).first
    inventory = Inventory.new(current_location[:name])
    messages = inventory.process_inventory_order order
    order.change_status Order::FINISHED
    flash[:notice] = messages
    redirect to('/inventory/inventory_imputation/select')
  end

  post '/inventory/inventory_imputation/:o_id/cancel' do
    order = Order.new.get_inventory_imputation.filter(o_id: params[:o_id].to_i).first
    if order.nil?
      flash[:error] = t.order.missing
    else
      order.cancel
      flash[:warning] = t.order.cancelled(params[:o_id].to_i)
    end
    redirect to("/inventory/inventory_imputation/select")
  end

end
