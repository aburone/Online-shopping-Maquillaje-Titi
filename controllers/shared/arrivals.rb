module Arrivals

  def redir_if_erroneous_item order, item
    if item.errors.count > 0 
      message = item.errors.to_a.flatten.join(": ")
      ActionsLog.new.set(msg: message, u_id: User.new.current_user_id, l_id: User.new.current_location[:name], lvl: ActionsLog::ERROR, o_id: order.o_id, p_id: item.p_id).save
      flash[:error_add_item] = item.errors
      redir = "/arrivals/#{order.o_id}" if order.type == Order::WH_TO_POS
      redir = "/logistics/transport/arrivals/#{order.o_id}" if order.type == Order::WH_TO_WH or order.type == Order::POS_TO_WH
      redirect to(redir)
    end
  end

  def redir_if_erroneous_order order, type
    if order.nil?
      flash[:error] = t.order.missing
      redir = '/arrivals/select' if type == Order::WH_TO_POS
      redir = "/logistics/transport/arrivals/select" if type == Order::WH_TO_WH or type == Order::POS_TO_WH
      redirect to(redir)
    end
  end


  def verify order, type, i_id = nil
    redir_if_erroneous_order order, type
    if i_id
      i_id = i_id.to_s.strip
      @item = Item.new.get_unverified_by_id i_id, order.o_id
      redir_if_erroneous_item order, @item
      begin    
        @item.change_status Item::VERIFIED, order.o_id
      rescue => detail
        flash.now[:error] = detail.message
        @item = Item.new
      end
    end

    @order = order
    @item ||= Item.new
    @product = @item.empty? ? Product.new : Product[@item.p_id]
    @pending_items = Item.join(:line_items, [:i_id]).filter(o_id: @order.o_id).filter(i_status: Item::MUST_VERIFY).all
    @verified_items = Item.join(:line_items, [:i_id]).filter(o_id: @order.o_id).filter(i_status: Item::VERIFIED).all
    @void_items = Item.join(:line_items, [:i_id]).filter(o_id: @order.o_id).filter(i_status: Item::VOID).all

    slim :verify_transport_order, layout: :layout_sales, locals: {sec_nav: :nav_sales_arrivals} if type == Order::WH_TO_POS
    slim :verify_transport_order, layout: :layout_backend, locals: {sec_nav: :nav_logistics, base_route: "/logistics/transport/arrivals"} if type == Order::WH_TO_WH or type == Order::POS_TO_WH
  end



  def finish_verification order

    @pending_items = Item.join(:line_items, [:i_id]).filter(o_id: order.o_id).filter(i_status: Item::MUST_VERIFY).all
    if @pending_items.count > 0
      flash[:error] = t.production.verifying_packaging.still_pending_items
      redir = "/arrivals/#{order.o_id}" if order.type == Order::WH_TO_POS
      redir = "/logistics/transport/arrivals/#{order.o_id}" if order.type == Order::WH_TO_WH or order.type == Order::POS_TO_WH
      redirect to(redir)
    else
      begin
        DB.transaction do
          if order.type == Order::WH_TO_POS or order.type == Order::WH_TO_WH or order.type == Order::POS_TO_WH
            order.change_status Order::VERIFIED
            order.items.each do |item| 
              item.change_status(Item::READY, order.o_id).save if item.i_status == Item::VERIFIED
            end
          end
        end
      rescue => e
        flash[:error] = e.message
      end
      redir = '/arrivals/select' if order.type == Order::WH_TO_POS
      redir = "/logistics/transport/arrivals/select" if order.type == Order::WH_TO_WH or order.type == Order::POS_TO_WH
      redirect to(redir)
    end
  end

end




class Sales < AppController
  include Arrivals

  get '/arrivals/items/?' do
    @pending_items = Item.new.get_in_location_with_status current_location[:name], Item::MUST_VERIFY
    @void_items = Item.new.get_in_location_with_status current_location[:name], Item::VOID
    slim :arrivals_items, layout: :layout_sales, locals: {sec_nav: :nav_sales_arrivals}
  end

  route :get, ["/arrivals", "/arrivals/select"] do
    @orders = Order.new.get_orders_in_destination_with_type_and_status(current_location[:name], Order::WH_TO_POS, Order::EN_ROUTE).all
    slim :orders_list, layout: :layout_sales, locals: {title: "Ingresos", sec_nav: :nav_sales_arrivals, full_row: true, list_mode: "transport", can_edit: true, edit_link: "/sales/arrivals/o_id"}
  end

  route :get, :post, '/arrivals/:o_id/?' do
    order = Order.new.get_orders_in_location_with_type_status_and_id(current_location[:name], Order::WH_TO_POS, Order::EN_ROUTE, params[:o_id])
    verify order, Order::WH_TO_POS, params[:i_id]
  end

  post '/arrivals/:o_id/:i_id/void' do 
    @item = Item[params[:i_id].to_s.strip]
    begin
      @item.change_status(Item::VOID, params[:o_id].to_i)
    rescue => detail
      flash.now[:error] = detail.message
    end
    slim :void_item, layout: :layout_sales, locals: {base_route: "/arrivals"}
  end

  post '/arrivals/:o_id/finish' do 
    finish_verification Order.new.get_orders_in_location_with_type_status_and_id(current_location[:name], Order::WH_TO_POS, Order::EN_ROUTE, params[:o_id])
  end
end



class Backend < AppController
  include Arrivals

  get '/logistics/transport/pending_items' do
    @pending_items = Item.new.get_in_location_with_status current_location[:name], Item::MUST_VERIFY
    @void_items = Item.new.get_in_location_with_status current_location[:name], Item::VOID
    slim :arrivals_items, layout: :layout_backend, locals: {sec_nav: :nav_logistics}
  end

  route :get, ["/logistics/transport/arrivals", "/logistics/transport/arrivals/select"] do
    @orders = Order.new.get_orders_in_destination_with_type_and_status(current_location[:name], [Order::WH_TO_WH, Order::POS_TO_WH], Order::EN_ROUTE).all
    slim :orders_list, layout: :layout_backend, locals: {title: "Ingresos", sec_nav: :nav_logistics, full_row: true, list_mode: "transport", can_edit: true, edit_link: "/admin/logistics/transport/arrivals/o_id"}
  end

  route :get, :post, '/logistics/transport/arrivals/:o_id' do
    order = Order.new.get_orders_in_location_with_type_status_and_id(current_location[:name], [Order::WH_TO_WH, Order::POS_TO_WH], Order::EN_ROUTE, params[:o_id])
    verify order, Order::WH_TO_WH, params[:i_id]
  end

  post '/arrivals/:o_id/:i_id/void' do 
    @item = Item[params[:i_id].to_s.strip]
    begin
      @item.change_status(Item::VOID, params[:o_id].to_i)
    rescue => detail
      flash.now[:error] = detail.message
    end
    slim :void_item, layout: :layout_backend, locals: {base_route: "/logistics/transport/arrivals"}
  end

  post '/logistics/transport/arrivals/:o_id/finish' do 
    finish_verification Order.new.get_orders_in_location_with_type_status_and_id(current_location[:name], [Order::WH_TO_WH, Order::POS_TO_WH], Order::EN_ROUTE, params[:o_id])
  end
end
