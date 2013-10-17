require 'sequel'

class Order < Sequel::Model
  many_to_many :items, class: :Item, join_table: :line_items, left_key: :o_id, right_key: :i_id

  TYPE_UNDEFINED="UNDEFINED"
  TYPE_PACKAGING="PACKAGING"
  INVENTORY="INVENTORY"
  WH_TO_POS="WH_TO_POS"
  SALE="SALE"

  OPEN="OPEN"
  MUST_VERIFY="MUST_VERIFY"
  VERIFIED="VERIFIED"
  FINISHED="FINISHED"
  VOID="VOID"

  def materials
    Material
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

  def remove_item item
    super
    message = R18n::t.order.item_removed
    ActionsLog.new.set(msg: message, u_id: User.new.current_user_id, l_id: User.new.current_location[:name], lvl: ActionsLog::NOTICE, i_id: item.i_id, p_id: item.p_id, o_id: @values[:o_id]).save
  end

  def remove_all_items
    super
    message = R18n::t.order.all_items_removed
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

  def to_s
    out = "\n"
    out += "#{self.class} #{sprintf("%x", self.object_id)}:\n"
    out += "\to_id:  #{@values[:o_id]}\n"
    out += "\ttype:  #{@values[:type]}\n"
    out += "\to_status:  #{@values[:o_status]}\n"
    out += "\to_loc:  #{@values[:o_loc]}\n"
    created = @values[:created_at] ? Utils::local_date_format(@values[:created_at]) : "Never"
    out += "\tcreated: #{created}\n"
    out
  end

  def cancel
    DB.transaction do
      items = self.items
      items.each { |item| item.dissociate @values[:o_id]}
      remove_all_items
      @values[:o_status] = Order::VOID
      save columns: [:o_id, :type, :o_status, :o_loc, :u_id, :created_at]
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

  def create_packaging
    create_new Order::TYPE_PACKAGING
  end

  def create_or_load_sale
    create_new Order::SALE
  end


  def get_orders
    Order
      .select(:o_id, :type, :o_status, :o_loc, :orders__created_at, :u_id, :username)
      .join(:users, user_id: :u_id)
  end

  def get_orders_in_location location
    get_orders
      .filter(o_loc: location.to_s)
  end

  def get_packaging_orders
    get_orders
      .filter(type: Order::TYPE_PACKAGING)
  end

  def get_packaging_orders_in_location location
    get_packaging_orders
      .filter(o_loc: location.to_s)
  end

  def get_packaging_order o_id, location
    order = get_packaging_orders_in_location(location)
      .filter(o_id: o_id.to_i)
      .filter(o_status: [Order::OPEN, Order::MUST_VERIFY])
      .first
    if order.class == Order
      return order
    else
      message = R18n.t.order.user_is_editing_nil(User.new.current_user_name, Order::TYPE_PACKAGING, o_id)
      ActionsLog.new.set(msg: message, u_id: User.new.current_user_id, l_id: User.new.current_location[:name], lvl: ActionsLog::ERROR).save 
      return Order.new
    end
  end

  def get_open_packaging_orders location
    get_packaging_orders
      .filter(o_status: Order::OPEN)
      .filter(o_loc: location.to_s)
  end

  def get_unverified_packaging_orders location
    Order
      .select(:o_id, :type, :o_status, :o_loc, :orders__created_at, :u_id, :username)
      .filter(type: Order::TYPE_PACKAGING)
      .filter(o_status: Order::MUST_VERIFY)
      .filter(o_loc: location.to_s)
      .join(:users, user_id: :u_id)
  end

  def get_packaging_order_for_verification o_id, location, log=true
    order = get_packaging_orders
      .filter(o_status: Order::MUST_VERIFY)
      .filter(o_id: o_id.to_i)
      .filter(o_loc: location.to_s)
      .first
    if order.class == Order
      if order.type == Order::TYPE_PACKAGING
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
      message = R18n.t.order.user_is_editing_nil(User.new.current_user_name, Order::TYPE_PACKAGING, o_id)
      ActionsLog.new.set(msg: message, u_id: User.new.current_user_id, l_id: location, lvl: ActionsLog::ERROR).save 
      order = Order.new
      order.errors.add("", message)
      return order
    end
  end

  def get_verified_packaging_orders location
    get_packaging_orders
      .filter(o_status: Order::VERIFIED)
      .filter(o_loc: location.to_s)
  end

  def get_order_for_allocation o_id, location
    get_packaging_orders
      .filter(o_status: Order::VERIFIED)
      .filter(o_id: o_id.to_i)
      .filter(o_loc: location.to_s)
      .first
  end

  def get_warehouse_pos location
    Order
      .select(:o_id, :type, :o_status, :orders__created_at, :u_id, :o_loc, :username)
      .filter(type: Order::WH_TO_POS)
      .filter(o_loc: location.to_s)
      .join(:users, user_id: :u_id)
  end

  def get_warehouse_pos__open location
    get_warehouse_pos(location).filter(o_status: Order::OPEN)
  end

  def get_warehouse_pos__open_by_id o_id, location
    get_warehouse_pos(location).filter(o_id: o_id.to_i)
  end

  def get_inventory_review
    get_orders
      .filter(type: Order::INVENTORY)
      .order(:o_id).reverse
  end

  def get_inventory_review_in_location location
     get_inventory_review
      .filter(o_loc: location.to_s)
  end

  def get_inventory_review_in_location_with_status location, status
     get_inventory_review_in_location(location)
      .filter(o_status: status.to_s)
  end

  def get_inventory_review_in_location_with_status_and_id location, status, o_id
    get_inventory_review_in_location_with_status(location, status)
      .filter(o_id: o_id.to_i)
      .first
  end

  def get_inventory_verification
    get_orders
      .filter(type: Order::INVENTORY)
      .filter(o_status: Order::MUST_VERIFY)
      .order(:o_id).reverse
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
end
