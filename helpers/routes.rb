module ApplicationHelper

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
    when /warehouse_pos/ # TODO: warehouse_pos -> wh_to_pos
      Order::WH_TO_POS
    when /wh_to_pos/
      Order::WH_TO_POS
    when /pos_to_hq/
      Order::POS_TO_WH
    end
  end

end
