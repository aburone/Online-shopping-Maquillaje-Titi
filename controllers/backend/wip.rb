require_relative 'production'

class Backend < AppController




  route :get, :post, ['/production/assembly/:o_id', '/production/assembly/:o_id/:p_id'] do
    ap "clusterfuck route assembly"
    # pass if params[:o_id].to_i == 0
    clusterfuck params, Order::ASSEMBLY
  end
  route :get, :post, ['/production/packaging/:o_id', '/production/packaging/:o_id/:p_id'] do
    ap "clusterfuck route assembly"
    clusterfuck params, Order::PACKAGING
  end
  route :get, :post, ['/production/allocation/:o_id', '/production/allocation/:o_id/:p_id'] do
    ap "clusterfuck route allocation"
    clusterfuck params, Order::ALLOCATION
  end

  def clusterfuck params, order_type
    order_type = order_type.downcase.to_sym
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
    # ap params
    # ap order
    product = Product.new
    products = []
    parts = []
    materials = []
    item ||= Item.new
    items = order.items
    ap items

    if params[:p_id]
      product = Product.new.get params[:p_id].to_i
      # ap product

      if params[:i_id]  && order_type_const != Order::ASSEMBLY
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


      elsif order_type_const == Order::ASSEMBLY
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
      case order_type_const
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
              title: eval("R18n.t.production.#{order_type}.title(order.o_id, items.count)"),
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
              title: eval("R18n.t.production.#{order_type}.title(order.o_id, items.count)"),
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
