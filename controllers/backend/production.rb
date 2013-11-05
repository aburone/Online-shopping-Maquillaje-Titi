class Backend < AppController

  get '/production/?' do
    slim :production, layout: :layout_backend, locals: {sec_nav: :nav_production}
  end


  get '/production/labels/?' do
    @labels = Label.new.get_unprinted.all
    @sec_nav = :nav_production
    slim :labels, layout: :layout_backend
  end
  get '/production/labels/list?' do
    unprinted = Label.new.get_unprinted.all
    printed = Label.new.get_printed.all
    @labels = unprinted + printed
    @sec_nav = :nav_production
    slim :labels, layout: :layout_backend
  end
  post '/production/labels/csv/?' do
    require 'tempfile'
    barcodes = Label.new.get_as_csv
    tmp = Tempfile.new(["barcodes", ".csv"])
    tmp << barcodes
    tmp.close
    send_file tmp.path, filename: 'barcodes.csv', type: 'octet-stream', disposition: 'attachment'
    tmp.unlink
  end
  post '/production/labels/new/?' do
    tmp = session[:locale]
    session[:locale] = 'es'
    Label.new.create params[:qty].to_i
    session[:locale] = tmp
    redirect to("/production/labels")
  end


  get '/production/packaging/select/?' do
    @sec_nav = :nav_production
    @orders = Order.new.get_open_packaging_orders current_location[:name]
    slim :packaging_order_select, layout: :layout_backend
  end
  get '/production/packaging/:o_id/?' do
    @sec_nav = :nav_production
    @order = Order.new.get_packaging_order params[:o_id].to_i, current_location[:name]
    if @order.o_id.nil?
      flash[:error] = t.order.missing
      redirect to("/production/packaging/select/")
    else
      @items = @order.items
      @title = t.order.title(@order.type, @order.o_id)
      slim :items_list, layout: :layout_backend
    end
  end
  post '/production/packaging/new/?' do
    tmp = session[:locale]
    session[:locale] = 'es'
    order = Order.new.create_packaging
    session[:locale] = tmp
    redirect to("/production/packaging/#{order.o_id}/add")
  end
  get '/production/packaging/:o_id/add/?' do
    @labels = Label.new.get_printed.all
    @products = Product.new.get_list.all
    @order = Order.new.get_packaging_order params[:o_id].to_i, current_location[:name]
    @items = @order.items
    slim :select_label_and_item_to_add_to_packaging_order, layout: :layout_backend
  end
  post '/production/packaging/:o_id/confirm/?' do
    @order = Order.new.get_packaging_order params[:o_id].to_i, current_location[:name]
    @product = Product[params[:product].to_i]
    @label = Item.filter(i_id: params[:label].to_s).first

    error = Validator.new.validate_packaging_order_params @order, @product, @label, params, session, flash
    redirect to("/production/packaging/#{params[:o_id].to_i}/add") if error

    slim :confirm_selected_product, layout: :layout_backend
  end
  post '/production/packaging/assign' do
    tmp = session[:locale]
    session[:locale] = 'es'
    order = Order.new.get_packaging_order params[:o_id].to_i, current_location[:name]
    the_redir = "/production/packaging/#{order.o_id}/add"
    product = Product[params[:p_id].to_i]
    label = Label.filter(i_id: params[:label].to_s).first
    assigned_msg = product.add_item label, order.o_id
    if product.errors.count > 0 
      flash[:error_add_item] = product.errors
    end

    item = Item[label.i_id]
    added_msg = order.add_item item
    item.change_status(Item::MUST_VERIFY, order.o_id)
    if order.errors.count > 0 
      flash[:error_add_item_to_order] = order.errors
    end

    flash[:notice] = [assigned_msg, added_msg]

    session[:locale] = tmp
    redirect to(the_redir)
  end
  post '/production/packaging/:o_id/finish_load/?' do
    order = Order.new.get_packaging_order params[:o_id].to_i, current_location[:name]
    order.finish_load
    flash[:notice] = t.order.ready_for_verification
    redirect to("/production/verify_packaging/select")
  end


  get '/production/verify_packaging/select/?' do
    @orders = Order.new.get_unverified_packaging_orders current_location[:name]
    slim :verify_packaging_select, layout: :layout_backend
  end
  route :get, :post, '/production/verify_packaging/:o_id/?' do
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

    @order = get_packaging_order_for_verification params
    @pending_items = Item.join(:line_items, [:i_id]).filter(o_id: @order.o_id).filter(i_status: Item::MUST_VERIFY).all
    @verified_items = Item.join(:line_items, [:i_id]).filter(o_id: @order.o_id).filter(i_status: Item::VERIFIED).all
    slim :verify_packaging_items, layout: :layout_backend
  end

  post '/production/verify_packaging/:o_id/:i_id/void/?' do 
    protected!
    order = Order[params[:o_id].to_i]
    @item = Item[params[:i_id].to_s.strip]
    order.remove_item(@item)
    begin
      @item.change_status(Item::VOID, params[:o_id].to_i)
    rescue => detail
      flash.now[:error] = detail.message
    end
    slim :void_item, layout: false
  end
  post "/production/verify_packaging/:o_id/finish" do
    @order = Order[params[:o_id].to_i]
    @pending_items = Item.join(:line_items, [:i_id]).filter(o_id: @order.o_id).filter(i_status: Item::MUST_VERIFY).all
    if @pending_items.count > 0
      flash[:error] = t.production.verifying_packaging.still_pending_items
      redirect to "/production/verify_packaging/#{@order.o_id}"
    else
      @order.change_status Order::VERIFIED
      redirect to("/production/packaging_orders_allocation/select/")
    end
  end

  post '/production/packaging/:o_id/cancel/?' do
    order = Order.new.get_packaging_order params[:o_id].to_i, current_location[:name]
    tmp = session[:locale]
    session[:locale] = 'es'
    if !order.o_id.nil?
      order.cancel
      session[:locale] = tmp
      flash[:warning] = t.order.cancelled(params[:o_id].to_i)
      the_redir = "/production/packaging/select"
    else
      flash[:error] = t.order.not_a_packaging
      the_redir = "/production/packaging/select"
    end
    redirect to(the_redir)
  end

  get '/production/packaging_orders_allocation/select/?' do
    @sec_nav = :nav_production
    @orders = Order.new.get_verified_packaging_orders current_location[:name]
    slim :packaging_orders_allocation_select, layout: :layout_backend
  end
  get '/production/packaging_orders_allocation/:o_id/?' do
    @sec_nav = :nav_production
    @order = Order.new.get_order_for_allocation(params[:o_id].to_i, current_location[:name])
    if @order 
      @items = @order.items
      inventory = Inventory.new(current_location[:name])
      inventory.can_complete_order? @order
      flash.now[:error] = inventory.errors
      @needed_materials = inventory.needed_materials
      @missing_materials = inventory.missing_materials
      @used_bulks = inventory.used_bulks
      slim :packaging_orders_allocation, layout: :layout_backend
    else
      flash[:error] = t.order.missing
      redirect to("/production/packaging_orders_allocation/select")
    end
  end
  post '/production/packaging_orders_allocation/:o_id/?' do
    order = Order.new.get_order_for_allocation(params[:o_id].to_i, current_location[:name])
    if order.nil?
      flash[:error] = t.order.missing
      redirect to("/production/packaging_orders_allocation/select")
    end
    inventory = Inventory.new(current_location[:name])
    begin
      inventory.process_packaging_order order
      flash[:notice] = t.production.packaging_order_allocation.ok(order.o_id)
      redirect to("/production/packaging_orders_allocation/select")
    rescue => detail
      flash[:error] = detail.message
      redirect to("/production/packaging_orders_allocation/#{order.o_id}")
    end
  end    




  def get_packaging_order_for_verification params
    tmp = session[:locale]
    session[:locale] = 'es'
    order = Order.new.get_packaging_order_for_verification params[:o_id].to_i, current_location[:name], request.env["REQUEST_METHOD"] == 'GET'
    session[:locale] = tmp
    if order.nil?
      flash[:error] = t.order.missing
      redirect to('/production/verify_packaging/select')
    else
      unless order.errors.values.join.empty?
        flash[:error] = order.errors.values.join
        redirect to('/production/verify_packaging/select')
      end
      return order
    end
  end


end
