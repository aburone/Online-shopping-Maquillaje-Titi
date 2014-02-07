module ApplicationHelper
  def redirect_if_has_errors object, redirect
    if object.errors.size > 0
      flash[:error] = object.errors.to_a.flatten.join(": ") 
      redirect to redirect
    end
  end

  def redirect_if_nil_item item, i_id, route
    if item.nil?
      flash[:error] = t.item.missing i_id
      redirect to(route)
    end
  end

  def redirect_if_nil_order order, o_id, route
    if order.nil?
      flash[:error] = t.order.missing o_id
      redirect to(route)
    end
  end

  def redirect_if_nil_bulk bulk, b_id, route
    if bulk.nil?
      flash[:error] = t.bulk.missing b_id
      redirect to(route)
    end
  end

  def o_type_from_route
    case env["sinatra.route"] 
    when /wh_to_wh/
      Order::WH_TO_WH 
    when /wh_to_pos/
      Order::WH_TO_POS
    when /pos_to_wh/
      Order::POS_TO_WH
    end
  end

end