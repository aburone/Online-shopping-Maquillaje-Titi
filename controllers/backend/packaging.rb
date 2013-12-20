class Backend < AppController

  get '/production/packaging/select' do
    @orders = Order.new.get_orders_in_location_with_type_and_status(current_location[:name], Order::PACKAGING, Order::OPEN)
    slim :production_select, layout: :layout_backend, locals: {sec_nav: :nav_logistics, mode: :packaging}
  end

  post '/production/packaging/new' do
    order = Order.new.create_new Order::PACKAGING
    redirect to("/production/packaging/#{order.o_id}")
  end

  post '/production/:o_id/cancel' do
    order = Order.new.get_orders_in_location_with_type_and_id(current_location[:name], Order::PACKAGING, params[:o_id].to_i)
    redirect_if_nil_order order, "packaging"
    destination = destination order
    order.cancel
    flash[:warning] = t.order.cancelled( order.o_id )
    redirect to("/production/#{destination}/select")
  end

  post '/production/packaging/:o_id/finish' do
    order = Order.new.get_orders_in_location_with_type_status_and_id(current_location[:name], Order::PACKAGING, Order::OPEN, params[:o_id].to_i)
    redirect_if_nil_order order, "packaging"

    order.finish_load
    if order.errors.count > 0 
      flash[:error_finish] = order.errors
      redirect to("/production/packaging/#{order.o_id}")
    end
    flash[:notice] = t.order.ready_for_verification
    redirect to("/production/verification/select")
  end


  route :get, :post, '/production/packaging/:o_id/item/remove' do
    @order = Order.new.get_orders_in_location_with_type_and_id(current_location[:name], Order::PACKAGING, params[:o_id].to_i)
    redirect_if_nil_order @order, "packaging"

    if params[:i_id].nil?
      slim :production_remove, layout: :layout_backend, locals: {sec_nav: :nav_logistics, title: t.production.remotion.title(@order.o_id)}
    else
      item = Item[params[:i_id].to_s.strip]
      if item.nil?
        flash[:error] = "No tengo ningun item con ese ID"
        middle = destination @order
        redirect to("/production/#{middle}/#{@order.o_id}")
      end

      if item.p_id.nil?
        flash[:error] = "Ese item no esta asignado a ningun producto"
        middle = destination @order
        redirect to("/production/#{middle}/#{@order.o_id}")
      end

      unless @order.items.include? item
        flash[:error] = "Ese item no pertenece a esta orden"
        middle = destination @order
        redirect to("/production/#{middle}/#{@order.o_id}")
      end

      product = Product[item.p_id]
      @order.remove_item item
      product.remove_item item
      if @order.errors.count > 0 or product.errors.count > 0
        fash[:error] = [@order.errors, product.errors]
      else
        flash[:warning] = "Etiqueta dissociada del producto y la orden. Podes asignarla a otro producto."
      end
      middle = destination @order
      redirect to("/production/#{middle}/#{@order.o_id}")
    end
  end


  def destination order
    case order.o_status
      when Order::OPEN
        return "packaging"
      when Order::MUST_VERIFY
        return "verification"
      when Order::VERIFIED
        return "allocation"
    end
  end


  route :get, :post, '/production/packaging/:o_id' do
    packaging params
  end
  route :get, :post, '/production/packaging/:o_id/:p_id' do
    packaging params
  end

  def packaging params
    @order = Order.new.get_orders_in_location_with_type_status_and_id(current_location[:name], Order::PACKAGING, Order::OPEN, params[:o_id].to_i)
    redirect_if_nil_order @order, "packaging"
    @product = []
    @products = []
    if params[:p_id]
      @product = Product.new.get params[:p_id].to_i
      if params[:i_id]
        i_id = params[:i_id].to_s.strip
        item =  Label.new.get_printed_by_id i_id, @order.o_id
        if item.errors.count > 0 
          message = item.errors.to_a.flatten.join(": ")
          ActionsLog.new.set(msg: message, u_id: User.new.current_user_id, l_id: User.new.current_location[:name], lvl: ActionsLog::ERROR, o_id: @order.o_id, p_id: @product.p_id).save
          flash[:error_add_item] = item.errors
          redirect to("/production/packaging/#{@order.o_id}/#{@product.p_id}")
        end

        assigned_msg = @product.add_item item, @order.o_id
        if @product.errors.count > 0 
          flash[:error_add_item] = @product.errors
          redirect to("/production/packaging/#{@order.o_id}/#{@product.p_id}")
        else
          @item = Item[i_id]
          added_msg = @order.add_item @item
          if @order.errors.count > 0 
            flash[:error_add_item_to_order] = @order.errors
            redirect to("/production/packaging/#{@order.o_id}/#{@product.p_id}")
          end
          @item.change_status(Item::MUST_VERIFY, @order.o_id)
        end
        flash[:notice] = [assigned_msg, added_msg]
      end
    else
      @products = Product.new.get_list.order(:c_name, :p_name).all
    end

    @item ||= Item.new
    @items = @order.items

    slim :production_add, layout: :layout_backend, locals: {sec_nav: :nav_logistics}
  end

  def redirect_if_nil_order order, step
    if order.nil?
      flash[:error] = t.order.missing
      redirect to("/production/#{step}/select")
    end
  end




  get '/production/verification/select' do
    @orders = Order.new.get_orders_in_location_with_type_and_status(current_location[:name], Order::PACKAGING, Order::MUST_VERIFY)
    slim :production_select, layout: :layout_backend, locals: {sec_nav: :nav_logistics, mode: :verification}
  end

  route :get, :post, '/production/verification/:o_id/?' do
    @order = Order.new.get_orders_in_location_with_type_status_and_id(current_location[:name], Order::PACKAGING, Order::MUST_VERIFY, params[:o_id].to_i)
    redirect_if_nil_order @order, "verification"

    @current_item = params[:i_id] ? Item[params[:i_id].to_s.strip] : nil
    if @current_item.nil?
      @current_item = Item.new 
      @current_product = Product.new
    else
      begin    
        @current_item.change_status Item::VERIFIED, params[:o_id].to_i
      rescue => detail
        flash.now[:error] = detail.message
        @current_item = Item.new
      end
      @current_product = @current_item.empty? ? Product.new : Product[@current_item.p_id]
    end

    @pending_items = Item.join(:line_items, [:i_id]).filter(o_id: @order.o_id).filter(i_status: Item::MUST_VERIFY).all
    @verified_items = Item.join(:line_items, [:i_id]).filter(o_id: @order.o_id).filter(i_status: Item::VERIFIED).all
    slim :production_verification, layout: :layout_backend, locals: {sec_nav: :nav_logistics}
  end

  post '/production/verification/:o_id/finish' do 
    @order = Order.new.get_orders_in_location_with_type_status_and_id(current_location[:name], Order::PACKAGING, Order::MUST_VERIFY, params[:o_id].to_i)
    redirect_if_nil_order @order, "verification"

    @pending_items = Item.join(:line_items, [:i_id]).filter(o_id: @order.o_id).filter(i_status: Item::MUST_VERIFY).all
    if @pending_items.count > 0
      flash[:error] = t.production.verification.still_pending_items
      redirect to "/production/verification/#{@order.o_id}"
    else
      @order.change_status Order::VERIFIED
      redirect to('/production/allocation/select')
    end
  end












  get '/production/allocation/select' do
    @orders = Order.new.get_orders_in_location_with_type_and_status(current_location[:name], Order::PACKAGING, Order::VERIFIED)
    slim :production_select, layout: :layout_backend, locals: {sec_nav: :nav_logistics, mode: :allocation}
  end





  get '/production/allocation/:o_id/?' do
    @order = Order.new.get_orders_in_location_with_type_status_and_id(current_location[:name], Order::PACKAGING, Order::VERIFIED, params[:o_id].to_i)
    redirect_if_nil_order @order, "allocation"

    @items = @order.items
    inventory = Inventory.new(current_location[:name])
    inventory.can_complete_order? @order
    flash.now[:error] = inventory.errors unless inventory.errors.empty?
    @needed_materials = inventory.needed_materials
    @missing_materials = inventory.missing_materials
    @used_bulks = inventory.used_bulks
    slim :production_allocation, layout: :layout_backend, locals: {sec_nav: :nav_logistics}
  end
  post '/production/allocation/:o_id/?' do
    order = Order.new.get_orders_in_location_with_type_status_and_id(current_location[:name], Order::PACKAGING, Order::VERIFIED, params[:o_id].to_i)
    redirect_if_nil_order order, "allocation"

    inventory = Inventory.new(current_location[:name])
    begin
      inventory.process_packaging_order order
      flash[:notice] = t.production.allocation.ok(order.o_id)
      redirect to("/production/allocation/select")
    rescue => detail
      flash[:error] = detail.message
      redirect to("/production/allocation/#{order.o_id}")
    end
  end    



  # get '/production/allocation/:o_id' do
  #   @order = Order.new.get_orders_in_location_with_type_status_and_id(current_location[:name], Order::PACKAGING, Order::VERIFIED, params[:o_id].to_i)
  #   redirect_if_nil_order @order, "allocation"

  #   @items = @order.items
  #   slim :production_allocation_confirm, layout: :layout_backend, locals: {sec_nav: :nav_logistics}
  # end

  # post '/production/allocation/:o_id/finish' do
  #   order = Order.new.get_inventory_imputation.filter(o_id: params[:o_id].to_i).first
  #   inventory = Inventory.new(current_location[:name])
  #   messages = inventory.process_inventory_order order
  #   order.change_status Order::FINISHED
  #   flash[:notice] = messages
  #   redirect to('/production/allocation/select')
  # end















########




  # def verification params
  #   @order = Order.new.get_orders_in_location_with_type_status_and_id(current_location[:name], Order::PACKAGING, Order::MUST_VERIFY, params[:o_id].to_i)
  #   redirect_if_nil_order @order, "verification"

  #   if params[:i_id]
  #     i_id = params[:i_id].to_s.strip
  #     @item = Item.new.get_unverified_by_id i_id, @order.o_id

  #     if @item.errors.count > 0 
  #       message = @item.errors.to_a.flatten.join(": ")
  #       ActionsLog.new.set(msg: message, u_id: User.new.current_user_id, l_id: User.new.current_location[:name], lvl: ActionsLog::ERROR, o_id: @order.o_id, p_id: @item.p_id).save
  #       flash[:error_add_item] = @item.errors
  #       redirect to("/production/verification/#{@order.o_id}")
  #     end

  #     begin    
  #       @item.change_status Item::VERIFIED, @order.o_id
  #     rescue => detail
  #       flash.now[:error] = detail.message
  #       @item = Item.new
  #     end
  #   end
  #   @item ||= Item.new
  #   @product = @item.empty? ? Product.new : Product[@item.p_id]
  #   @pending_items = Item.join(:line_items, [:i_id]).filter(o_id: @order.o_id).filter(i_status: Item::MUST_VERIFY).all
  #   @verified_items = Item.join(:line_items, [:i_id]).filter(o_id: @order.o_id).filter(i_status: Item::VERIFIED).all
  #   slim :production_verification, layout: :layout_backend, locals: {sec_nav: :nav_logistics}
  # end

  # route :get, :post, '/production/verification/:o_id' do
  #   verification params
  # end




end


