
class Backend < AppController

  get '/production' do
    slim :admin, layout: Thread.current.thread_variable_get(:layout), locals: {sec_nav: :nav_production, title: t.production.title}
  end

  get '/production/labels/?' do
    @labels = Label.new.get_unprinted.all
    @sec_nav = :nav_production
    slim :labels, layout: :layout_backend, locals: {sec_nav: :nav_production, title: t.labels.title}
  end
  get '/production/labels/list' do
    unprinted = Label.new.get_unprinted.all
    printed = Label.new.get_printed.all
    @labels = unprinted + printed
    @sec_nav = :nav_production
    slim :labels, layout: :layout_backend, locals: {sec_nav: :nav_production, title: t.labels.title}
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
    Label.new.create params[:qty].to_i
    redirect to("/production/labels")
  end


  post '/production/verification/:o_id/:i_id/void' do
    @order = Order[params[:o_id].to_i]
    @item = Item[params[:i_id].to_s.strip]
    @order.remove_item(@item)
    begin
      @item.change_status(Item::VOID, params[:o_id].to_i)
    rescue => detail
      flash.now[:error] = detail.message
    end
    slim :void_item, layout: false, locals: {show_backtrack: false}
  end





  def poor_redirect_if_nil_order order, step
    if order.nil?
      flash[:error] = t.order.missing
      redirect to("/production/#{step}/select")
    end
  end

  get '/production/:order_type/select' do
    order_type = params[:order_type].to_sym
    case order_type
      when :assembly
        route = "assembly"
        order_type_const = Order::ASSEMBLY
        order_status_const = Order::OPEN
        title = t.production.assembly_select.title
      when :packaging
        route = "packaging"
        order_type_const = Order::PACKAGING
        order_status_const = Order::OPEN
        title = t.production.packaging_select.title
      when :verification
        route = "verification"
        order_type_const = Order::PACKAGING
        order_status_const = Order::MUST_VERIFY
        title = t.production.verification_select.title
      when :allocation
        route = "allocation"
        order_type_const = Order::PACKAGING
        order_status_const = Order::VERIFIED
        title = t.production.allocation_select.title
      else
        flash[:error] = params
        redirect to("/production")
    end
    orders = Order.new.get_orders_at_location_with_type_and_status(current_location[:name], order_type_const, order_status_const).all
    slim :production_select, layout: :layout_backend, locals: {sec_nav: :nav_production, orders: orders, mode: order_type, title: title}
  end

  route :get, :post, '/production/verification/:o_id/?' do
    @order = Order.new.get_orders_at_location_with_type_status_and_id(current_location[:name], Order::PACKAGING, Order::MUST_VERIFY, params[:o_id].to_i)
    poor_redirect_if_nil_order @order, "verification"
    if params[:i_id]
      @current_item = Item.new.get_for_verification params[:i_id], @order.o_id
      redirect_if_nil_item @current_item, params[:i_id], "/production/verification/#{@order.o_id}"
      begin
        @current_item.change_status Item::VERIFIED, params[:o_id].to_i
        flash.now[:notice] = t.verification.ok @current_item.i_id, @current_item.p_name
      rescue => detail
        flash.now[:error] = detail.message
        @current_item = Item.new
      end
    end
    @current_item ||= Item.new
    @current_product = @current_item.empty? ? Product.new : Product[@current_item.p_id]

    @pending_items = Item.join(:line_items, [:i_id]).filter(o_id: @order.o_id).filter(i_status: Item::MUST_VERIFY).order(:p_name).all
    @verified_items = Item.join(:line_items, [:i_id]).filter(o_id: @order.o_id).filter(i_status: Item::VERIFIED).order(:p_name).all
    slim :verify_packaging, layout: :layout_backend, locals: {sec_nav: :nav_production, title: t.production.verification.title(@order.o_id, @verified_items.count, @pending_items.count+@verified_items.count )}
  end

  get '/production/allocation/:o_id' do
    @order = Order.new.get_orders_at_location_with_type_status_and_id(current_location[:name], Order::PACKAGING, Order::VERIFIED, params[:o_id].to_i)
    poor_redirect_if_nil_order @order, "allocation"

    @items = @order.items
    inventory = Inventory.new(current_location[:name])
    inventory.can_complete_order? @order
    flash.now[:error] = inventory.errors unless inventory.errors.empty?
    @needed_materials = inventory.needed_materials
    @missing_materials = inventory.missing_materials
    @used_bulks = inventory.used_bulks
    slim :production_allocation, layout: :layout_backend, locals: {sec_nav: :nav_production}
  end
  post '/production/allocation/:o_id' do
    order = Order.new.get_orders_at_location_with_type_status_and_id(current_location[:name], Order::PACKAGING, Order::VERIFIED, params[:o_id].to_i)
    poor_redirect_if_nil_order order, "allocation"

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


  post '/production/:order_type/new' do
    order_type = params[:order_type].to_sym
    case order_type
      when :assembly
        route = "assembly"
        order_type_const = Order::ASSEMBLY
      when :packaging
        route = "packaging"
        order_type_const = Order::PACKAGING
      when :allocation
        route = "allocation"
        order_type_const = Order::PACKAGING
      else
        route = "invalid"
        order_type_const = nil
    end
    order = Order.new.create_or_load order_type_const
    redirect to("/production/#{order_type}/#{order.o_id}")
  end

  route :get, :post, '/production/packaging/:o_id/item/remove' do
    flash.now[:notice] = "Lee La etiqueta recien agregada" if env["REQUEST_METHOD"] == "POST"

    @order = Order.new.get_orders_at_location_with_type_and_id(current_location[:name], Order::PACKAGING, params[:o_id].to_i)
    poor_redirect_if_nil_order @order, "packaging"

    if params[:id].nil?
      slim :remove_item, layout: :layout_backend, locals: {sec_nav: :nav_production, action_url: "/production/packaging/#{@order.o_id}/item/remove", title: t.production.remotion.title(@order.o_id)}
    else
      item = Item[params[:id].to_s.strip]
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
        flash[:error] = [@order.errors, product.errors]
      else
        flash[:warning] = "Etiqueta dissociada del producto y la orden. Podes asignarla a otro producto."
      end
      middle = destination @order
      redirect to("/production/#{middle}/#{@order.o_id}")
    end
  end

  post '/production/:order_type/:o_id/finish' do
    order_type = params[:order_type].to_sym
    case order_type
      when :assembly
        route = "assembly"
        order_type_const = Order::ASSEMBLY
        order_status_const = Order::OPEN
      when :packaging
        route = "packaging"
        order_type_const = Order::PACKAGING
        order_status_const = Order::OPEN
      when :verification
        route = "verification"
        order_type_const = Order::PACKAGING
        order_status_const = Order::MUST_VERIFY
      when :allocation
        route = "allocation"
        order_type_const = Order::PACKAGING
        order_status_const = Order::VERIFIED
      else
        route = "invalid"
        order_type_const = nil
    end
    order = Order.new.get_orders_at_location_with_type_status_and_id(current_location[:name], order_type_const, order_status_const, params[:o_id].to_i)
    poor_redirect_if_nil_order order, order_type
    cancel_and_redirect order if order.items.empty?
    finish_and_redirect order
  end

  post '/production/:order_type/:o_id/cancel' do
    order_type = params[:order_type].to_sym
    case order_type
      when :assembly
        route = "assembly"
        order_type_const = Order::ASSEMBLY
      when :packaging
        route = "packaging"
        order_type_const = Order::PACKAGING
      when :allocation
        route = "allocation"
        order_type_const = Order::PACKAGING
      else
        route = "invalid"
        order_type_const = nil
    end
    order = Order.new.get_orders_at_location_with_type_and_id(current_location[:name], order_type_const, params[:o_id].to_i)
    poor_redirect_if_nil_order order, route
    cancel_and_redirect order
  end

  def finish_and_redirect order
    routes = [:packaging, :verification, :allocation]
    if order.type ==  Order::PACKAGING && order.o_status == Order::OPEN
      order.finish_load
      ok_message = t.order.ready_for_verification
      route = 1
    elsif order.type ==  Order::PACKAGING && order.o_status == Order::MUST_VERIFY
      order.finish_verification
      ok_message = t.order.ready_for_allocation
      route = 2
    elsif order.type ==  Order::ALLOCATION && order.o_status == Order::VERIFIED
      order.finish_verification
      ok_message = t.order.ready_for_allocation
      route = 3
    end

    if order.errors.count > 0
      flash[:error_finish] = order.errors
      redirect to("/production/#{routes[route-1]}/#{order.o_id}")
    else
      flash[:notice] = ok_message
      redirect to("/production/#{routes[route]}/select")
    end
  end

  def cancel_and_redirect order
    order.cancel
    flash[:warning] = t.order.cancelled( order.o_id )
    redirect to("/production/packaging/select")
  end

  route :get, :post, ['/production/:order_type/:o_id', '/production/:order_type/:o_id/:p_id'] do
    ap "clusterfuck route"
    pass if params[:o_id].to_i == 0
    clusterfuck params
  end

  def clusterfuck params
    order_type = params[:order_type].to_sym
    o_id = params[:o_id].to_i
    case order_type
      when :assembly
        route = "assembly"
        order_type_const = Order::ASSEMBLY
        order_status_const = Order::OPEN
      when :packaging
        route = "packaging"
        order_type_const = Order::PACKAGING
        order_status_const = Order::OPEN
      when :allocation
        route = "allocation"
        order_type_const = Order::PACKAGING
        order_status_const = Order::VERIFIED
      else
        raise "Tipo de orden invalido \"#{order_type}\""
    end

    order = Order.new.get_orders_at_location_with_type_status_and_id(current_location[:name], order_type_const, order_status_const, o_id)
    poor_redirect_if_nil_order order, route
    product = []
    products = []
    if params[:p_id]
      product = Product.new.get params[:p_id].to_i
      if params[:i_id]
        i_id = params[:i_id].to_s.strip
        item =  Label.new.get_printed_by_id i_id, order.o_id
        if item.errors.count > 0
          message = item.errors.to_a.flatten.join(": ")
          ActionsLog.new.set(msg: message, u_id: User.new.current_user_id, l_id: User.new.current_location[:name], lvl: ActionsLog::ERROR, o_id: order.o_id, p_id: product.p_id).save
          flash[:error_add_item] = item.errors
          redirect to("/production/#{route}/#{order.o_id}/#{product.p_id}")
        end

        assigned_msg = product.add_item item, order.o_id
        if product.errors.count > 0
          flash[:error_add_item] = product.errors
          redirect to("/production/#{route}/#{order.o_id}/#{product.p_id}")
        else
          item = Item[i_id]
          added_msg = order.add_item item
          if order.errors.count > 0
            flash[:error_add_item_to_order] = order.errors
            redirect to("/production/#{route}/#{order.o_id}/#{product.p_id}")
          end
          item.change_status(Item::MUST_VERIFY, order.o_id)
        end
        flash[:notice] = [assigned_msg, added_msg]
      end
    else
      case order_type
        when :assembly
          products = Product.new.get_all.filter(Sequel.lit('parts_cost > 0')).filter(archived: 0).all
        when :packaging
          products = Product.new.get_all_but_archived.order(:c_name, :p_name).all
      else
          products = []
      end
    end

    item ||= Item.new
    items = order.items
    slim :production_add, layout: :layout_backend,
          locals: {
            sec_nav: :nav_production,
            title: eval("R18n.t.production.#{order_type}.title(order.o_id, items.count)"),
            order: order,
            product: product,
            products: products,
            item: item,
            items: items
          }
  end



  def destination order
    case order.o_status
      when Order::OPEN
        return order.type.downcase
      when Order::MUST_VERIFY
        return "verification"
      when Order::VERIFIED
        return "allocation"
    end
  end


end
