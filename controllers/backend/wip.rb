# coding: UTF-8
require_relative 'production'

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





  route :post, ['/production/:order_type/new'] do
    order_type = params[:order_type].upcase
    unless Order::PRODUCTION_TYPES.include? order_type
      flash[:error] = "Tipo de orden inválido"
      redirect to("/production")
    end
    order = Order.new.create_or_load order_type
    redirect to("/production/#{order_type.downcase}/#{order.o_id}")
  end


  get '/production/:action/select' do
    unless Order::PRODUCTION_ACTIONS.include? params[:action].upcase
      flash[:error] = "Tipo de acción inválida"
      redirect to("/production")
    end

    action = params[:action].to_sym
    case action
      when :assembly
        order_type = Order::ASSEMBLY
        order_status = Order::OPEN
        title = t.production.assembly_select.title
      when :packaging
        order_type = Order::PACKAGING
        order_status = Order::OPEN
        title = t.production.packaging_select.title
      when :verification
        order_type = Order::PACKAGING
        order_status = Order::MUST_VERIFY
        title = t.production.verification_select.title
      when :allocation
        order_type = Order::PACKAGING
        order_status = Order::VERIFIED
        title = t.production.allocation_select.title
    end
    orders = Order.new.get_orders_at_location_with_type_and_status(current_location[:name], order_type, order_status).all
    slim :production_select, layout: :layout_backend, locals: {sec_nav: :nav_production, orders: orders, action: action, title: title}
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
    slim :void_item, layout: false, locals: {show_backlink: false}
  end


  route :get, :post, '/production/verification/:o_id/?' do
    order = Order.new.get_orders_at_location_with_type_status_and_id(current_location[:name], Order::PACKAGING, Order::MUST_VERIFY, params[:o_id].to_i)
    redirect_if_nil_order order, params[:o_id].to_i, "/production/verification/select"

    if params[:i_id]
      current_item = Item.new.get_for_verification params[:i_id], order.o_id
      redirect_if_nil_item( current_item, params[:i_id].to_s.strip, "/production/verification/#{order.o_id}" )
      begin
        current_item.change_status Item::VERIFIED, params[:o_id].to_i
        flash.now[:notice] = t.verification.ok current_item.i_id, current_item.p_name
      rescue => detail
        flash.now[:error] = detail.message
      end
    end
    current_item ||= Item.new
    current_product = current_item.empty? ? Product.new : Product[current_item.p_id]
    pending_items = Item.join(:line_items, [:i_id]).filter(o_id: order.o_id).filter(i_status: Item::MUST_VERIFY).order(:p_name).all
    verified_items = Item.join(:line_items, [:i_id]).filter(o_id: order.o_id).filter(i_status: Item::VERIFIED).order(:p_name).all
    slim :verify_packaging, layout: :layout_backend, locals: {
      order: order, current_product: current_product, current_item: current_item, pending_items: pending_items, verified_items: verified_items,
      sec_nav: :nav_production, title: t.production.verification.title(order.o_id, verified_items.count, pending_items.count+verified_items.count )}
  end


  get '/production/allocation/:o_id' do
    order = Order.new.get_orders_at_location_with_type_status_and_id(current_location[:name], Order::PACKAGING, Order::VERIFIED, params[:o_id].to_i)
    redirect_if_nil_order order, params[:o_id].to_i, "/production/allocation/select"

    inventory = Inventory.new(current_location[:name])
    inventory.can_complete_order? order
    flash.now[:error] = inventory.errors unless inventory.errors.empty?

    slim :production_allocation, layout: :layout_backend, locals: {
      order: order, items: order.items, needed_materials: inventory.needed_materials, missing_materials: inventory.missing_materials, used_bulks: inventory.used_bulks,
      sec_nav: :nav_production, title: t.production.allocation.title(order.o_id)}
  end

  post '/production/allocation/:o_id' do
    order = Order.new.get_orders_at_location_with_type_status_and_id(current_location[:name], Order::PACKAGING, Order::VERIFIED, params[:o_id].to_i)
    redirect_if_nil_order order, params[:o_id].to_i, "/production/allocation/select"

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


  route :get, :post, '/production/packaging/:o_id/item/remove' do
    flash.now[:notice] = "Lee La etiqueta recien agregada" if env["REQUEST_METHOD"] == "POST" && params[:id].nil?

    order = Order.new.get_orders_at_location_with_type_and_id(current_location[:name], Order::PACKAGING, params[:o_id].to_i)
    redirect_if_nil_order order, params[:o_id].to_i, "/production/packaging/select"

    if params[:id].nil?
      @order = order
      slim :remove_item, layout: :layout_backend, locals: {sec_nav: :nav_production, action_url: "/production/packaging/#{order.o_id}/item/remove", title: t.production.remotion.title(order.o_id)}
    else
      item = Item[params[:id].to_s.strip]
      if item.nil?
        flash[:error] = "No tengo ningun item con ese ID"
        redirect to("/production/#{order.current_action}/#{order.o_id}")
      end
      if item.p_id.nil?
        flash[:error] = "Ese item no esta asignado a ningun producto"
        redirect to("/production/#{order.current_action}/#{order.o_id}")
      end
      unless order.items.include? item
        flash[:error] = "Ese item no pertenece a esta orden"
        redirect to("/production/#{order.current_action}/#{order.o_id}")
      end
      product = Product[item.p_id]
      order.remove_item item
      product.remove_item item
      if order.errors.count > 0 or product.errors.count > 0
        flash[:error] = [order.errors, product.errors]
      else
        flash[:warning] = "Etiqueta dissociada del producto y la orden. Podes asignarla a otro producto."
      end
      redirect to("/production/#{order.current_action}/#{order.o_id}")
    end
  end



  post '/production/:action/:o_id/finish' do
    unless Order::PRODUCTION_ACTIONS.include? params[:action].upcase
      flash[:error] = "Tipo de acción inválida"
      redirect to("/production")
    end

    action = params[:action].to_sym
    case action
      when :assembly
        order_type = Order::ASSEMBLY
        order_status = Order::OPEN
      when :packaging
        order_type = Order::PACKAGING
        order_status = Order::OPEN
      when :verification
        order_type = Order::PACKAGING
        order_status = Order::MUST_VERIFY
      when :allocation
        order_type = Order::PACKAGING
        order_status = Order::VERIFIED
    end
    order = Order.new.get_orders_at_location_with_type_status_and_id(current_location[:name], order_type, order_status, params[:o_id].to_i)
    redirect_if_nil_order order, params[:o_id].to_i, "/production/#{action}/select"
    cancel_and_redirect order if order.items.empty?
    finish_and_redirect order
  end

  post '/production/:action/:o_id/cancel' do
    unless Order::PRODUCTION_ACTIONS.include? params[:action].upcase
      flash[:error] = "Tipo de acción inválida"
      redirect to("/production")
    end

    action = params[:action].to_sym
    case action
      when :assembly
        order_type = Order::ASSEMBLY
      when :packaging
        order_type = Order::PACKAGING
      when :allocation
        order_type = Order::PACKAGING
    end
    order = Order.new.get_orders_at_location_with_type_and_id(current_location[:name], order_type, params[:o_id].to_i)
    redirect_if_nil_order order, params[:o_id].to_i, "/production/#{action}/select"
    cancel_and_redirect order
  end






  def poor_redirect_if_nil_order order, step
    if order.nil?
      flash[:error] = t.order.missing
      redirect to("/production/#{step}/select")
    end
  end












  def finish_and_redirect order
    if order.type ==  Order::ASSEMBLY
      routes = [:assembly, :verification, :allocation]
      order.finish_assembly
      ok_message = t.order.ready_for_allocation
      route = 1
    else
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
    redirect to("/production/#{order.type.downcase}/select")
  end














  route :get, :post, ['/production/packaging/:o_id', '/production/packaging/:o_id/:p_id'] do
    ap "clusterfuck route packaging"
    clusterfuck params, Order::PACKAGING
  end
  route :get, :post, ['/production/allocation/:o_id', '/production/allocation/:o_id/:p_id'] do
    ap "clusterfuck route allocation"
    clusterfuck params, Order::ALLOCATION
  end

  def clusterfuck params, action
    action = action.downcase.to_sym
    o_id = params[:o_id].to_i
    case action
      when :assembly
        route = "assembly"
        order_type = Order::ASSEMBLY
        order_status = Order::OPEN
      when :packaging
        route = "packaging"
        order_type = Order::PACKAGING
        order_status = Order::OPEN
      when :allocation
        route = "allocation"
        order_type = Order::PACKAGING
        order_status = Order::VERIFIED
      else
        raise "Tipo de acción inválida \"#{action}\""
    end

    order = Order.new.get_orders_at_location_with_type_status_and_id(current_location[:name], order_type, order_status, o_id)
    redirect_if_nil_order order, o_id, "/production/#{route}/select"

    # ap params
    # ap order
    product = Product.new
    products = []
    parts = []
    materials = []
    item ||= Item.new
    items = order.items
    # ap items

    if params[:p_id]
      product = Product.new.get params[:p_id].to_i
      # ap product

      if params[:i_id]  && order_type != Order::ASSEMBLY
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


      elsif order_type == Order::ASSEMBLY
        parts = product.parts
        parts.reject! { |part| included? part, items }
        if params[:i_id]
          i_id = params[:i_id].to_s.strip
          item =  Item.new.get_for_assembly i_id, order.o_id, parts.first.p_id
          # ap item

          if item.errors.count > 0
            message = item.errors.to_a.flatten.join(": ")
            ActionsLog.new.set(msg: message, u_id: User.new.current_user_id, l_id: User.new.current_location[:name], lvl: ActionsLog::ERROR, o_id: order.o_id, p_id: product.p_id).save
            flash[:error_add_item] = item.errors
            redirect to("/production/#{route}/#{order.o_id}/#{product.p_id}")
          end
          added_msg = order.add_item item
          if order.errors.count > 0
            flash[:error_add_item_to_order] = order.errors
            redirect to("/production/#{route}/#{order.o_id}/#{product.p_id}")
          end
          item.change_status(Item::IN_ASSEMBLY, order.o_id)
        end
      end
    else
      case order_type
        when Order::ASSEMBLY
          products = Product.new.get_all_but_archived.filter(Sequel.lit('parts_cost > 0')).order(:p_name).all
        when Order::PACKAGING
          products = Product.new.get_all_but_archived.filter(Sequel.lit('parts_cost = 0')).order(:c_name, :p_name).all
      else
          products = []
      end
    end

    # ap parts

    if parts.empty?
      slim :production_add, layout: :layout_backend,
            locals: {
              sec_nav: :nav_production,
              title: eval("R18n.t.production.#{action}.title(order.o_id, items.count)"),
              order: order,
              product: product,
              products: products,
              item: item,
              items: items,
              parts: parts,
              materials: materials
            }
    else
      materials = product.materials
      bulks = order.bulks

      materials = materials - bulks

      if materials
        p "Materiales"
        materials.each do |material|
          p "#{material.m_name} - #{material.category.c_name} (#{material.category.c_id}) [#{material.class}]"
        end
      end
      if parts
        p "Partes"
        parts.each do |part|
          p "#{part.p_name} - #{part.category.c_name} (#{part.category.c_id}) [#{part.class}]"
        end
      end

      slim :production_kits_add, layout: :layout_backend,
            locals: {
              sec_nav: :nav_production,
              title: eval("R18n.t.production.#{action}.title(order.o_id, items.count)"),
              order: order,
              product: product,
              item: item,
              items: items,
              bulks: bulks,
              parts: parts,
              materials: materials
            }
    end
  end

  def included? part, items
  items.each do |item|
      # ap "#{item.p_name} (#{item.p_id})"
      # ap "#{part.p_name} (#{part.p_id})"
      # p ""
     return true if item.p_id == part.p_id
   end
   return false
  end









  route :get, :post, ['/production/assembly/:o_id', '/production/assembly/:o_id/:p_id'] do
    ap "clusterfuck route assembly"
    # pass if params[:o_id].to_i == 0
    clusterfuck_assembly params, Order::ASSEMBLY
  end


  def get_next_part product, items
    p "sdf"
    parts = product.parts
    parts.reject! { |part| included? part, items }
    ap parts
    parts.empty? ? Product.new : parts.first
  end

  def clusterfuck_assembly params, action
    action = action.downcase.to_sym
    o_id = params[:o_id].to_i
    case action
      when :assembly
        route = "assembly"
        order_type = Order::ASSEMBLY
        order_status = Order::OPEN
      else
        raise "Tipo de acción inválida \"#{action}\""
    end

    order = Order.new.get_orders_at_location_with_type_status_and_id(current_location[:name], order_type, order_status, o_id)
    redirect_if_nil_order order, o_id, "/production/#{route}/select"

    # ap params
    ap order
    ap order.items
    ap order.materials


    product = Product.new
    products = []
    parts = []
    next_part = Product.new
    materials = []
    item ||= Item.new
    items = order.items
    # ap items

    if params[:p_id]
      product = Product.new.get params[:p_id].to_i
      ap "Armando: #{product.p_name} (#{product.p_id})"

      next_part = get_next_part product, items
      ap "esperando: #{next_part.p_name} (#{next_part.p_id})" unless next_part.empty?

      if params[:i_id]
        i_id = params[:i_id].to_s.strip
        item =  Item.new.get_for_assembly i_id, order.o_id, next_part.p_id
        ap "Ingresado #{item.p_name} (#{item.p_id})"
        if item.errors.count > 0
          message = item.errors.to_a.flatten.join(": ")
          ActionsLog.new.set(msg: message, u_id: User.new.current_user_id, l_id: User.new.current_location[:name], lvl: ActionsLog::ERROR, o_id: order.o_id, p_id: product.p_id).save
          flash[:error_add_item] = item.errors
          redirect to("/production/#{route}/#{order.o_id}/#{product.p_id}")
        end
        if order.errors.count > 0
          flash[:error_add_item_to_order] = order.errors
          redirect to("/production/#{route}/#{order.o_id}/#{product.p_id}")
        end

        added_msg = order.add_item item
        status_msg = item.change_status(Item::IN_ASSEMBLY, order.o_id)
        flash.now[:notice] = [added_msg, status_msg]

        items = order.items
        next_part = get_next_part product, items
        ap "Ahora esperando: #{next_part.p_name} (#{next_part.p_id})"
      end

      materials = product.materials
      bulks = order.bulks

      materials = materials - bulks

      unless materials.empty?
        p ""
        p "Materiales faltantes"
        materials.each do |material|
          ap "#{material.m_name} - #{material.category.c_name} (#{material.category.c_id}) [#{material[:c_name]}]"
        end
      end
      unless parts.empty?
        p ""
        p "Partes faltantes"
        parts.each do |part|
          ap "#{part.p_name} - #{part.category.c_name} (#{part.category.c_id}) [#{part.class}]"
        end
      end

      ""
      ap next_part
      slim :production_kits_add, layout: :layout_backend,
            locals: {
              sec_nav: :nav_production,
              title: eval("R18n.t.production.#{action}.title(order.o_id, items.count)"),
              order: order,
              product: product,
              item: item,
              items: items,
              bulks: bulks,
              parts: parts,
              next_part: next_part,
              materials: materials
            }

    else
      products = Product.new.get_all_but_archived.filter(Sequel.lit('parts_cost > 0')).order(:p_name).all
      slim :production_add, layout: :layout_backend,
            locals: {
              sec_nav: :nav_production,
              title: eval("R18n.t.production.#{action}.title(order.o_id, items.count)"),
              order: order,
              product: product,
              products: products,
              item: item,
              items: items,
              parts: parts,
              materials: materials
            }
    end


  end


end
