require 'sequel'
class Order < Sequel::Model

  def create type
    u = User.new
    current_user_id = u.current_user_id
    current_location_name = u.current_location[:name]

    order = Order.create(type: type, o_status: Order::OPEN, u_id: current_user_id, o_loc: current_location_name)
    order = Order[order.o_id]
    message = R18n.t.order.created(order.type)
    ActionsLog.new.set(msg: message, u_id: User.new.current_user_id, l_id: current_location_name, lvl:  ActionsLog::NOTICE, o_id: order.o_id).save
    order
  end

  def create_or_load( type )
    u = User.new
    current_user_id = u.current_user_id
    current_location_name = u.current_location[:name]
    order = Order
              .filter(type: type)
              .filter(o_status: Order::OPEN, u_id: current_user_id, o_loc: current_location_name)
              .order(:created_at)
              .first
    order = self.create type if order.nil?
    order
  end

  def create_or_load_return sale_id
    return_order = create_or_load Order::RETURN
    return_order.create_or_load_return_association sale_id
    return_order
  end

  def create_or_load_return_association sale_id
    if self.type == Order::RETURN
      str = SalesToReturn.filter(return: self.o_id).first
      str = SalesToReturn.new.set_all(sale: sale_id, return: self.o_id).save if str.nil?
      raise ArgumentError, R18n::t.errors.sale_id_missmatch unless str.sale == sale_id
      @values[:sale_id] = str.sale
    end
  end

  def create_invalidation origin
    u = User.new
    current_user_id = u.current_user_id
    order = Order.create(type: Order::INVALIDATION, o_status: Order::OPEN, u_id: current_user_id, o_loc: origin, o_dst: Location::VOID)
    message = R18n.t.order.created(order.type)
    ActionsLog.new.set(msg: message, u_id: User.new.current_user_id, l_id: origin, lvl:  ActionsLog::NOTICE, o_id: order.o_id).save
    order
  end

  def create_transmutation origin
    u = User.new
    current_user_id = u.current_user_id
    order = Order.create(type: Order::TRANSMUTATION, o_status: Order::OPEN, u_id: current_user_id, o_loc: origin, o_dst: Location::VOID)
    message = R18n.t.order.created(order.type)
    ActionsLog.new.set(msg: message, u_id: User.new.current_user_id, l_id: origin, lvl:  ActionsLog::NOTICE, o_id: order.o_id).save
    order
  end

  def get_orders
    Order
      .select(:o_id, :o_code, :type, :o_status, :o_loc, :o_dst, :orders__created_at, :u_id, :username)
      .join(:users, user_id: :u_id)
  end


  def get_orders_at_location location
    get_orders
      .filter( Sequel.or(o_loc: location.to_s, o_dst: location.to_s) )
  end

  def get_orders_at_destination location
    get_orders
      .filter( o_dst: location.to_s)
  end

  def get_orders_with_type type
    get_orders
      .filter(type: type)
  end

  def get_orders_at_location_with_type location, type
    get_orders_at_location(location)
      .filter(type: type)
  end

  def get_orders_at_location_with_type_and_status location, type, o_status
    get_orders_at_location_with_type( location, type)
      .filter( o_status: o_status)
  end

  def get_orders_at_destination_with_type_and_status location, type, o_status
    get_orders_at_destination( location )
      .filter(type: type)
      .filter( o_status: o_status)
  end

  def get_orders_at_location_with_type_status_and_id location, type, o_status, o_id
    o_id = o_id.to_i
    get_orders_at_location_with_type_and_status( location, type, o_status)
      .filter(o_id: o_id)
      .first
  end

  def get_orders_at_location_with_type_status_and_code location, type, o_status, o_code
    return Order.new if o_code.nil?
    o_code = o_code.to_s.strip

    order = get_orders_at_location_with_type_and_status( location, type, o_status)
      .filter(o_code: remove_dash_from_code(o_code.to_s))
      .first
    if order.nil?
      order = Order.new
      order.errors.add R18n.t.errors.inexistent_order.to_s, R18n.t.errors.invalid_order_id.to_s
    end
    order
  end

  def get_orders_at_location_with_type_and_id location, type, o_id
    get_orders_at_location_with_type(location, type)
      .filter(o_id: o_id)
      .first
  end

  def get_packaging_orders
    get_orders_with_type Order::PACKAGING
  end

  def get_packaging_orders_in_location location
    get_orders_at_location_with_type location, Order::PACKAGING
  end

  def get_packaging_order o_id, location
    order = get_packaging_orders_in_location(location)
      .filter(o_id: o_id.to_i)
      .filter(o_status: [Order::OPEN, Order::MUST_VERIFY])
      .first
    if order.class == Order
      return order
    else
      message = R18n.t.order.user_is_editing_nil(User.new.current_user_name, Order::PACKAGING, o_id)
      ActionsLog.new.set(msg: message, u_id: User.new.current_user_id, l_id: User.new.current_location[:name], lvl: ActionsLog::ERROR).save
      return Order.new
    end
  end

  def get_open_packaging_orders location
    get_packaging_orders_in_location(location)
      .filter(o_status: Order::OPEN)
  end

  def get_unverified_packaging_orders location
    get_packaging_orders_in_location(location)
      .filter(o_status: Order::MUST_VERIFY)
  end

  def get_packaging_order_for_verification o_id, location, log=true
    order = get_packaging_orders_in_location(location)
      .filter(o_status: Order::MUST_VERIFY)
      .filter(o_id: o_id.to_i)
      .first
    if order.class == Order
      if order.type == Order::PACKAGING
        if order.o_status == Order::MUST_VERIFY
          message = R18n.t.order.user_is_verifying(User.new.current_user_name, order.type, order.o_id)
          ActionsLog.new.set(msg: message, u_id: User.new.current_user_id, l_id: location, lvl: ActionsLog::NOTICE, o_id: order.o_id).save if log
          return order
        else
          message = R18n.t.order.user_is_verfying_order_in_invalid_status(User.new.current_user_name, order.type, order.o_id, order.o_status)
          ActionsLog.new.set(msg: message, u_id: User.new.current_user_id, l_id: location, lvl: ActionsLog::ERROR, o_id: order.o_id).save
          order = Order.new
          order.errors.add("", message)
          return order
        end
      else
        message = R18n.t.order.user_is_verfying_order_of_wrong_type(User.new.current_user_name, order.o_id, order.o_status, order.type)
        ActionsLog.new.set(msg: message, u_id: User.new.current_user_id, l_id: location, lvl: ActionsLog::ERROR, o_id: order.o_id).save
        order = Order.new
        order.errors.add("", message)
        return order
      end
    else
      order = Order.new
      message = R18n.t.order.user_is_editing_nil(User.new.current_user_name, Order::PACKAGING, o_id)
      ActionsLog.new.set(msg: message, u_id: User.new.current_user_id, l_id: location, lvl: ActionsLog::ERROR).save
      order = Order.new
      order.errors.add("", message)
      return order
    end
  end

  def get_verified_packaging_orders location
    get_packaging_orders_in_location(location)
      .filter(o_status: Order::VERIFIED)
  end

  def get_order_for_allocation o_id, location
    get_packaging_orders
      .filter(o_status: Order::VERIFIED)
      .filter(o_id: o_id.to_i)
      .filter( Sequel.or(o_loc: location.to_s, o_dst: location.to_s) )
      .first
  end

  def get_wh_to_pos
    get_orders
      .filter(type: Order::WH_TO_POS)
  end

  def get_wh_to_pos__open location
    get_wh_to_pos
      .filter( Sequel.or(o_loc: location.to_s, o_dst: location.to_s) )
      .filter(o_status: Order::OPEN)
  end

  def get_wh_to_pos__open_by_id o_id, location
    get_wh_to_pos
      .filter( Sequel.or(o_loc: location.to_s, o_dst: location.to_s) )
      .filter(o_id: o_id.to_i)
  end

  def get_wh_to_pos__en_route destination
    get_wh_to_pos
      .filter(o_dst: destination.to_s)
      .filter(o_status: Order::EN_ROUTE)
  end

  def get_wh_to_pos__en_route_by_id destination, o_id
    get_wh_to_pos__en_route(destination)
      .filter(o_id: o_id.to_i)
      .first
  end

  def get_inventory_imputation
    get_orders
      .filter(type: Order::INVENTORY)
      .filter(o_status: Order::VERIFIED)
      .order(:o_id).reverse
  end

  def items_as_cart
    Item
      .select(:p_id, :p_name, :i_price, :i_price_pro)
      .select_append{sum(1).as(qty)}
      .join(:line_items, line_items__i_id: :items__i_id)
      .join(:orders, line_items__o_id: :orders__o_id, orders__o_id: @values[:o_id])
      .group(:p_id, :p_name, :i_price, :i_price_pro)
  end

  def items_as_cart_detailed
    Item
      .select(:items__i_id, :p_name, :i_price, :i_price_pro)
      .select_append( Sequel.as(Sequel.lit("1"), :qty) )
      .join(:line_items, line_items__i_id: :items__i_id)
      .join(:orders, line_items__o_id: :orders__o_id, orders__o_id: @values[:o_id])
      .group(:items__i_id, :p_name, :i_price, :i_price_pro)
  end

  def cart_total
    Item
      .select{sum(:i_price).as(total)}
      .join(:line_items, line_items__i_id: :items__i_id)
      .join(:orders, line_items__o_id: :orders__o_id, orders__o_id: @values[:o_id])
      .first[:total]
  end

  def credit_total
    credit_total = Line_payment
      .select{abs(sum(:payment_ammount)).as(total)}
      .filter(o_id: self.o_id)
      .first[:total]
    return credit_total.nil? ? 0 : credit_total
  end

end