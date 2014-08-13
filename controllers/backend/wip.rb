# coding: UTF-8
require_relative 'production'
require_relative 'labels'
require_relative 'production_utils'

class Backend < AppController

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
      inventory.process_order order
      flash[:notice] = t.production.allocation.ok(order.o_id)
      redirect to("/production/allocation/select")
    rescue => detail
      flash[:error] = detail.message
      redirect to("/production/allocation/#{order.o_id}")
    end
  end


  post '/production/assembly/:o_id/allocate' do
    order = Order.new.get_orders_at_location_with_type_status_and_id(current_location[:name], Order::ASSEMBLY, Order::OPEN, params[:o_id].to_i)
    ap params
    ap order
    product = order.get_assembly
    ap product.p_name
    order.items.each { |p| ap p.p_name }

    product.materials.each { |m| ap m.m_name }

    id_label =  Label.new.get_printed_by_id params[:label_id], order.o_id
    ap id_label


    halt
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

    if item.errors.count > 0
      message = item.errors.to_a.flatten.join(": ")
      ActionsLog.new.set(msg: message, u_id: User.new.current_user_id, l_id: User.new.current_location[:name], lvl: ActionsLog::ERROR, o_id: order.o_id, p_id: product.p_id).save
      flash[:error_add_item] = item.errors
      redirect to("/production/#{route}/#{order.o_id}/#{product.p_id}")
    end


     redirect_if_nil_order order, params[:o_id].to_i, "/production/allocation/select"

    inventory = Inventory.new(current_location[:name])
    begin
      inventory.process_assembly_order order
      flash[:notice] = t.production.allocation.ok(order.o_id)
      redirect to("/production/assembly/select")
    rescue => detail
      flash[:error] = detail.message
      redirect to("/production/assembly/#{order.o_id}")
    end
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

    product = Product.new
    products = []
    item ||= Item.new
    items = order.items

    if params[:p_id]
      product = Product.new.get params[:p_id].to_i
      # ap product

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
        when Order::PACKAGING
          products = Product.new.get_all_but_archived.filter(Sequel.lit('parts_cost = 0')).order(:c_name, :p_name).all
      else
          products = []
      end
    end

    slim :production_add, layout: :layout_backend,
          locals: {
            sec_nav: :nav_production,
            title: eval("R18n.t.production.#{action}.title(order.o_id, items.count)"),
            order: order,
            product: product,
            products: products,
            item: item,
            items: items,
          }
  end








  route :get, ['/production/assembly/:o_id/:p_id'] do
    o_id = params[:o_id].to_i
    p_id = params[:p_id].to_i
    order = Order.new.get_orders_at_location_with_type_status_and_id(current_location[:name], Order::ASSEMBLY, Order::OPEN, o_id)
    redirect_if_nil_order order, o_id, "/production/assembly/select"
    product = Product.new.get_assembly p_id
    redirect_if_empty_or_nil product, "/production/assembly/select"
    begin
      Assembly_order_to_product.new.create order.o_id, product.p_id
    rescue Sequel::UniqueConstraintViolation
      flash[:error] = "La orden ya estaba asignada a un kit"
      redirect to "/production/assembly/#{order.o_id}"
    end
    redirect to "/production/assembly/#{order.o_id}"
  end

  route :get, :post, ['/production/assembly/:o_id'] do
    ap "clusterfuck route assembly"
    # pass if params[:o_id].to_i == 0
    clusterfuck_assembly params, Order::ASSEMBLY
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

    item ||= Item.new
    items = []
    missing_parts = []
    added_parts = []
    product = order.get_assembly
    unless product.empty?
      p "Armando"
      ap "#{product.p_name} (#{product.p_id})"

      p "Partes necesarias"
      needed_parts = product.parts
      needed_parts.each { |part| ap "#{part.p_name} - #{part.category.c_name} (#{part.category.c_id}) [#{part.class}]" }

      p "Partes agregadas"
      added_parts = order.items
      added_parts.each { |part| ap "#{part.p_name} - #{part.category.c_name} (#{part.category.c_id}) [#{part.class}]" }

      p "Partes por agregar"
      missing_parts = needed_parts - added_parts
      missing_parts.each { |part| ap "#{part.p_name} - #{part.category.c_name} (#{part.category.c_id}) [#{part[:c_name]}]" }

      if params[:i_id]
        i_id = params[:i_id].to_s.strip
        item =  Item.new.get_for_assembly i_id, order.o_id, missing_parts

        ap "Ingresado #{item.p_name} (#{item.p_id})"
        if item.errors.count > 0
          message = item.errors.to_a.flatten.join(": ")
          ActionsLog.new.set(msg: message, u_id: User.new.current_user_id, l_id: User.new.current_location[:name], lvl: ActionsLog::ERROR, o_id: order.o_id, p_id: product.p_id).save
          flash[:error_add_item] = item.errors
          redirect to("/production/#{route}/#{order.o_id}")
        end
        if order.errors.count > 0
          flash[:error_add_item_to_order] = order.errors
          redirect to("/production/#{route}/#{order.o_id}")
        end

        added_msg = order.add_item item
        status_msg = item.change_status(Item::IN_ASSEMBLY, order.o_id)
        flash.now[:notice] = [added_msg, status_msg]

        #reload
        added_parts = order.items
        missing_parts = needed_parts - added_parts
      end




      p "Materiales necesarios"
      needed_materials = product.materials
      needed_materials.each { |material| ap "#{material.m_name} - #{material.category.c_name} (#{material.category.c_id}) [#{material[:c_name]}]" }

      p "Materiales agregados"
      added_materials = order.bulks
      added_materials.each { |material| ap "#{material.m_name} - #{material.category.c_name} (#{material.category.c_id}) [#{material[:c_name]}]" }

      p "Materiales por agregar"
      missing_materials = needed_materials - added_materials #will not work
      missing_materials.each { |material| ap "#{material.m_name} - #{material.category.c_name} (#{material.category.c_id}) [#{material[:c_name]}]" }

      packaging = Material.new
      label_1 = Material.new
      label_2 = Material.new
      if missing_parts.empty?
        missing_materials.each do |material|
          if material[:c_name] == "Packaging"
            packaging = material.dup
            missing_materials -= [material]
            break
          end
        end

        missing_materials.each do |material|
          if material[:c_name] == "Etiquetas preimpresas"
            label_1 = material.dup
            missing_materials -= [material]
            break
          end
        end

        p "Materiales por agregar despues de etiqueta"
        ap missing_materials

        label_2 = Material[108]
      end

      slim :production_kits_add, layout: :layout_backend,
            locals: {
              sec_nav: :nav_production,
              title: eval("R18n.t.production.#{action}.title(order.o_id, added_parts.count)"),
              order: order,
              product: product,
              item: item,
              missing_parts: missing_parts,
              added_parts: added_parts,
              missing_materials: missing_materials,
              packaging: packaging,
              label_1: label_1,
              label_2: label_2
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
              items: items
            }
    end


  end


end
