require 'sequel'

class Order < Sequel::Model
  many_to_many :items, class: :Item, join_table: :line_items, left_key: :o_id, right_key: :i_id
  many_to_many :bulks, class: :Bulk, join_table: :line_bulks, left_key: :o_id, right_key: :b_id

  PACKAGING="PACKAGING"
  INVENTORY="INVENTORY"
  WH_TO_POS="WH_TO_POS"
  POS_TO_WH="POS_TO_WH"
  WH_TO_WH="WH_TO_WH"
  SALE="SALE"
  RETURN="RETURN"
  CREDIT_NOTE="CREDIT_NOTE"
  INVALIDATION="INVALIDATION"
  TRANSMUTATION="TRANSMUTATION"
  TYPES = [PACKAGING, INVENTORY, WH_TO_POS, POS_TO_WH, WH_TO_WH, SALE, INVALIDATION, TRANSMUTATION]

  OPEN="OPEN"
  MUST_VERIFY="MUST_VERIFY"
  VERIFIED="VERIFIED"
  FINISHED="FINISHED"
  EN_ROUTE="EN_ROUTE"
  VOID="VOID"

  def empty?
    return @values[:o_id].nil? ? true : false
  end

  def remove_dash_from_code code
    code.to_s.gsub('-', '')
  end

  def o_code_with_dash
    self.o_code.upcase.insert(3, '-') unless self.o_code.nil?
  end

  def valid_type? type
    TYPES.include? type
  end

  def items
    super
  end

  def bulks
    super
  end

  def materials
    materials = Material
      .select(:materials__m_id, :m_name, :c_id)
      .select_append(:c_name)
      .join(:products_materials, [:m_id])
      .join(:products, products__p_id: :products_materials__product_id)
      .join(:items, [:p_id])
      .join(:line_items, line_items__i_id: :items__i_id, o_id: self.o_id)
      .join(:materials_categories, materials_categories__c_id: :materials__c_id)
      .select_group(:m_id, :m_name, :c_name, :materials__c_id)
      .select_append{sum(:m_qty).as(m_qty)}
      .all
    materials.each do |mat|
      mat[:m_qty] = BigDecimal.new(mat[:m_qty], 3)
    end
    materials
  end

  def parts
    parts = []
    self.items.each do |item|
      parts << Product.new.get(item.p_id).parts
    end
    parts.flatten
  end

  def add_item item
    current_user_id = User.new.current_user_id
    current_location = User.new.current_location[:name]
    if item.nil?
      message = R18n::t.errors.inexistent_item
      ActionsLog.new.set(msg: "#{message}", u_id: current_user_id, l_id: current_location, lvl:  ActionsLog::ERROR).save
      errors.add "General", message
      return message
    end
    if item.class != Item
      message = R18n::t.errors.this_is_not_an_item(item.class)
      ActionsLog.new.set(msg: "#{message}", u_id: current_user_id, l_id: current_location, lvl:  ActionsLog::ERROR).save
      errors.add "General", message
      return message
    end
    if item.i_status == Item::NEW
      message = R18n::t.errors.label_wasnt_printed
      ActionsLog.new.set(msg: message, u_id: current_user_id, l_id: current_location, lvl:  ActionsLog::ERROR, i_id: item.i_id, p_id: item.p_id).save
      errors.add "General", message
      return message
    end
    begin
      if super
        added_msg = R18n::t.order.item_added(item.p_name, @values[:o_id])
        ActionsLog.new.set(msg: added_msg, u_id: current_user_id, l_id: current_location, lvl:  ActionsLog::NOTICE, i_id: item.i_id, p_id: item.p_id, o_id: @values[:o_id]).save
        return added_msg
      else
        ActionsLog.new.set(msg: this.errors.to_s, u_id: current_user_id, l_id: current_location, lvl:  ActionsLog::ERROR, i_id: item.i_id, p_id: item.p_id).save
        return this.errors.to_s
      end
    rescue => detail
      print detail.message
    end
  end

  def add_bulk bulk
    current_user_id = User.new.current_user_id
    current_location = User.new.current_location[:name]
    if bulk.nil?
      message = R18n::t.errors.inexistent_bulk
      ActionsLog.new.set(msg: "#{message}", u_id: current_user_id, l_id: current_location, lvl:  ActionsLog::ERROR).save
      errors.add "General", message
      return message
    end
    if bulk.class != Bulk
      message = R18n::t.errors.this_is_not_a_bulk(bulk.class)
      ActionsLog.new.set(msg: "#{message}", u_id: current_user_id, l_id: current_location, lvl:  ActionsLog::ERROR).save
      errors.add "General", message
      return message
    end
    if bulk.b_status == Bulk::UNDEFINED
      message = R18n::t.errors.bulk_in_undefined_status
      ActionsLog.new.set(msg: message, u_id: current_user_id, l_id: current_location, lvl:  ActionsLog::ERROR, b_id: bulk.b_id, m_id: bulk.m_id).save
      errors.add "General", message
      return message
    end
    if @values[:type] != Order::WH_TO_WH
      message = R18n::t.errors.not_a_inter_warehouse_order
      ActionsLog.new.set(msg: message, u_id: current_user_id, l_id: current_location, lvl:  ActionsLog::ERROR, b_id: bulk.b_id, m_id: bulk.m_id, o_id: @values[:o_id]).save
      errors.add "General", message
      return message
    end

    begin
      if super
        added_msg = R18n::t.order.bulk_added(bulk.m_id, @values[:o_id])
        ActionsLog.new.set(msg: added_msg, u_id: current_user_id, l_id: current_location, lvl:  ActionsLog::NOTICE, b_id: bulk.b_id, m_id: bulk.m_id, o_id: @values[:o_id]).save
        return added_msg
      else
        ActionsLog.new.set(msg: this.errors.to_s, u_id: current_user_id, l_id: current_location, lvl:  ActionsLog::ERROR, b_id: bulk.b_id, m_id: bulk.m_id).save
        return this.errors.to_s
      end
    rescue => detail
      print detail.message
    end
  end

  def remove_item item
    super
    message = R18n::t.order.item_removed
    ActionsLog.new.set(msg: message, u_id: User.new.current_user_id, l_id: User.new.current_location[:name], lvl: ActionsLog::NOTICE, i_id: item.i_id, p_id: item.p_id, o_id: @values[:o_id]).save
  end

  def remove_bulk bulk
    super
    message = R18n::t.order.bulk_removed
    ActionsLog.new.set(msg: message, u_id: User.new.current_user_id, l_id: User.new.current_location[:name], lvl: ActionsLog::NOTICE, b_id: bulk.b_id, m_id: bulk.m_id, o_id: @values[:o_id]).save
  end

  def remove_all_items
    super
    message = R18n::t.order.all_items_removed
    ActionsLog.new.set(msg: message, u_id: User.new.current_user_id, l_id: User.new.current_location[:name], lvl: ActionsLog::NOTICE, o_id: @values[:o_id]).save
  end

  def remove_all_bulks
    super
    message = R18n::t.order.all_bulks_removed
    ActionsLog.new.set(msg: message, u_id: User.new.current_user_id, l_id: User.new.current_location[:name], lvl: ActionsLog::NOTICE, o_id: @values[:o_id]).save
  end

  def finish_load
    change_status Order::MUST_VERIFY
  end

  def change_status status
    @values[:o_status] = status
    save columns: [:o_status]
    ActionsLog.new.set(msg: R18n.t.actions.changed_status(ConstantsTranslator.new(status).t), u_id: User.new.current_user_id, l_id: User.new.current_location[:name], lvl: ActionsLog::NOTICE, o_id: @values[:o_id]).save
    self
  end

  def print
    out = "\n"
    out += "#{self.class} #{sprintf("%x", self.object_id)}:\n"
    out += "\to_id:  #{@values[:o_id]}\n"
    out += "\ttype:  #{@values[:type]}\n"
    out += "\to_status:  #{@values[:o_status]}\n"
    out += "\to_loc:  #{@values[:o_loc]}\n"
    out += "\to_dst:  #{@values[:o_dst]}\n"
    out += "\tu_id:   #{@values[:u_id]}\n"
    created = @values[:created_at] ? Utils::local_datetime_format(@values[:created_at]) : "Never"
    out += "\tcreated: #{created}\n"
    echo out
  end

  def cancel
    DB.transaction do
      items = self.items
      items.each { |item| item.dissociate @values[:o_id]}
      remove_all_items
      @values[:o_status] = Order::VOID
      save columns: [:o_id, :type, :o_status, :o_loc, :o_dst, :u_id, :created_at]
      message = R18n.t.order.void
      ActionsLog.new.set(msg: message, u_id: User.new.current_user_id, l_id: User.new.current_location[:name], lvl: ActionsLog::NOTICE, o_id: @values[:o_id]).save
    end
  end

  def cancel_sale
    DB.transaction do
      items = self.items
      items.each do |item|
        message = "Removiendo #{item.p_name} de la orden #{@values[:o_id]}"
        ActionsLog.new.set(msg: message, u_id: User.new.current_user_id, l_id: User.new.current_location[:name], lvl: ActionsLog::NOTICE, o_id: @values[:o_id], i_id: item.i_id, p_id: item.p_id).save
        item.change_status Item::READY, @values[:o_id]
      end
      remove_all_items
      @values[:o_status] = Order::VOID
      save columns: [:o_id, :type, :o_status, :o_loc, :u_id, :created_at]
      message = R18n.t.order.void
      ActionsLog.new.set(msg: message, u_id: User.new.current_user_id, l_id: User.new.current_location[:name], lvl: ActionsLog::NOTICE, o_id: @values[:o_id]).save
    end
  end

  def create_new type
    u = User.new
    current_user_id = u.current_user_id
    current_location = u.current_location[:name]

    order = Order
              .filter(type: type)
              .filter(o_status: Order::OPEN, u_id: current_user_id, o_loc: current_location)
              .order(:created_at)
              .first
    if order.class ==  NilClass
      order = Order
              .create(type: type, o_status: Order::OPEN, u_id: current_user_id, o_loc: current_location)
      message = R18n.t.order.created(order.type)
      ActionsLog.new.set(msg: message, u_id: User.new.current_user_id, l_id: current_location, lvl:  ActionsLog::NOTICE, o_id: order.o_id).save
    end
    order
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

  def create_packaging #TODO: eliminar de los test y borrar
    create_new Order::PACKAGING
  end

  def create_or_load_sale
    create_new Order::SALE
  end


  def get_orders
    Order
      .select(:o_id, :o_code, :type, :o_status, :o_loc, :o_dst, :orders__created_at, :u_id, :username)
      .join(:users, user_id: :u_id)
  end

  def get_order_by_code code
    order = get_orders
      .filter( o_code: remove_dash_from_code(code))
      .first
    if order.nil?
      order = Order.new
      order.errors.add(t.errors.inexistent_order.to_s, t.errors.invalid_order.to_s)
    end
    order
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
    get_orders_at_location_with_type_and_status( location, type, o_status)
      .filter(o_id: o_id)
      .first
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

  def cart_total
    Item
      .select{sum(:i_price).as(total)}
      .join(:line_items, line_items__i_id: :items__i_id)
      .join(:orders, line_items__o_id: :orders__o_id, orders__o_id: @values[:o_id])
      .first[:total]
  end

  def recalculate_as( type )
    case type.to_sym
    when :Profesional
      message = "Aplicado descuento a profesionales"
      DB.transaction do
        items = self.items
        items.each do |item|
          item.i_price = item.i_price_pro if item.i_price_pro > 0
          item.save
        end
      end
    when :Regular
      message = "Utilizando precios de lista"
      DB.transaction do
        items = self.items
        items.each do |item|
          item.i_price = Product[item.p_id].price if item.i_price_pro > 0
          item.save
        end
      end
    end
    message
  end

  def types_at_location location
    orders = Order.
      select(:type)
      .filter( Sequel.or(o_loc: location, o_dst: location) )
      .group(:type)
      .all
    types = []
    orders.each { |order| types << order.type}
    types
  end
end
