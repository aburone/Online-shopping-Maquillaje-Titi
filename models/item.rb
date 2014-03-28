require 'sequel'
require_relative 'order'
require_relative '../helpers/sequel_binary'

class Item < Sequel::Model
  many_to_one :product, key: :p_id
  many_to_many :orders, class: :Order, join_table: :line_items, left_key: :i_id, right_key: :o_id

  NEW         ="NEW"
  PRINTED     ="PRINTED"
  ASSIGNED    ="ASSIGNED"
  MUST_VERIFY ="MUST_VERIFY"
  VERIFIED    ="VERIFIED"
  READY       ="READY"
  ERROR       ="ERROR"
  VOID        ="VOID"
  ON_CART     ="ON_CART"
  SOLD        ="SOLD"
  RETURNING   ="RETURNING"
  ATTRIBUTES = [:i_id, :p_id, :p_name, :i_price, :i_price_pro, :i_status, :i_loc, :created_at]

  @sale_id = 666

  def split_input_into_ids input
    ids = []
    input.split("\n").map { |id| ids << id.to_s.strip unless id.to_s.strip.empty?}
    ids
  end

  def check_io input, output
    return [] if input.count == output.count
    output.each { |item| input.delete(item.i_id)}
    input
  end

  def check_reason reason
    reason.strip!
    raise ArgumentError, "Es necesario especificar la razon para invalidar el item" if reason.length < 5
    reason
  end

  def save (opts=OPTS)
    opts = opts.merge({columns: Item::ATTRIBUTES})
    begin
      super opts
    rescue => message
      errors.add "General", message
    end
    self
  end

  def void! reason
    reason = check_reason reason
    begin
      DB.transaction do
        self.orders.dup.each do |order|
          order.remove_item self unless order.o_status == Order::VOID or order.o_status == Order::FINISHED
        end
      end
      order = Order.new.create_invalidation @values[:i_loc]
      change_status_security_check Item::VOID, order.o_id
    rescue SecurityError => e
      order.change_status Order::FINISHED
      raise SecurityError, e.message
    end
    origin = @values[:i_loc].dup
    @values[:i_loc] = Location::VOID
    @values[:i_status] = Item::VOID
    order.add_item self
    save validate: false

    message = "#{R18n.t.actions.changed_status(ConstantsTranslator.new(Item::VOID).t)}. Razon: #{reason}"
    log = ActionsLog.new.set(msg: message, u_id: User.new.current_user_id, l_id: origin, lvl: ActionsLog::WARN, i_id: @values[:i_id], o_id: order.o_id)
    log.set(p_id: @values[:p_id]) unless @values[:p_id].nil?
    log.save

    product = Product[self.p_id]
    product.update_stocks.save unless product.nil?

    order.change_status Order::FINISHED
    message
  end

  def check_product_for_transmutation p_id
    p_id = p_id.to_i
    product = Product[p_id]
    raise ArgumentError, R18n.t.product.missing(p_id) if product.nil?
    raise ArgumentError, R18n.t.product.errors.archived if product.archived
    product
  end

  def transmute! reason, p_id
    raise SecurityError if @values[:i_status] != Item::READY
    reason = check_reason reason
    product = check_product_for_transmutation p_id
    original = self.dup

    order = Order.new.create_transmutation User.new.current_location[:name]
    order.add_item self
    @values[:p_id] = product.p_id
    @values[:p_name] = product.p_name
    @values[:i_price] = product.price
    @values[:i_price_pro] = product.price_pro
    save

    message = "Item Transmutado: #{original.p_name} -> #{@values[:p_name]}. Razon: #{reason}"
    log = ActionsLog.new.set(msg: message, u_id: User.new.current_user_id, l_id: @values[:i_loc], lvl: ActionsLog::WARN, o_id: order.o_id, i_id: @values[:i_id], p_id: @values[:p_id])
    log.save

    product = Product[original.p_id]
    product.update_stocks.save unless product.nil?
    product = Product[self.p_id]
    product.update_stocks.save unless product.nil?

    order.change_status Order::FINISHED


    self
  end


  def empty?
    return @values[:i_id].nil? ? true : false
  end

  def update_from item
    @values[:i_id] = item.i_id
    @values[:p_id] = item.p_id
    @values[:p_name] = item.p_name
    @values[:i_price] = item.i_price
    @values[:i_price_pro] = item.i_price_pro
    @values[:i_status] = item.i_status
    @values[:i_loc] = item.i_loc
    @values[:created_at] = item.created_at

    @sale_id = item[:sale] if item[:sale]
    @sale_id ||= item.o_id if item.o_id
    self
  end

  def sale_id
    @sale_id
  end

  def o_id
    @values[:o_id]
  end

  def order_missmatch sale_id
    return false if self.sale_id == sale_id
    errors.add("Error de ingreso", "Este item pertenece a la orden #{self.sale_id}, mientras que la orden de venta actual es la #{sale_id}.")
    return true
  end

  def missing i_id
    if Item[i_id].nil?
      errors.add("Etiqueta inválida", "No tengo ningun item con el id '#{i_id}'")
      return true
    end
    return false
  end

  def is_from_production
    if @values[:i_status] == Item::NEW or @values[:i_status] == Item::PRINTED or @values[:i_status] == Item::ASSIGNED or @values[:i_status] == Item::MUST_VERIFY or @values[:i_status] == Item::VERIFIED
      errors.add("Item fuera de lugar", "Este item esta en estado \"#{ConstantsTranslator.new(@values[:i_status]).t}\". Ni siquiera deberia estar en el local.")
      return true
    end
    return false
  end

  def is_from_another_location
    if @values[:i_loc] != User.new.current_location[:name]
      errors.add("Item fuera de lugar", "Este item pertenece a \"#{ConstantsTranslator.new(@values[:i_loc]).t}\". Ni siquiera deberia estar aqui.")
      return true
    end
    return false
  end

  def current_sale_order
    Order
      .select(:orders__o_id, :type, :o_status, :o_loc, :u_id, :orders__created_at)
      .join(:line_items, line_items__o_id: :orders__o_id, orders__type: Order::SALE)
      .join(:items, line_items__i_id: :items__o_id, line_items__i_id: @values[:i_id])
      .first
  end

  def is_on_cart o_id
    return false unless @values[:i_status] == Item::ON_CART
    order = current_sale_order
    if o_id == current_sale_order.o_id
      errors.add("Error de carga", "Este item ya fue agregado a la orden actual con anterioridad.")
      return true
    else
      errors.add("Item en otra venta en curso", "Este item pertenece a la orden #{order.o_id}. Que haces agregandolo a esta orden??")
      return true
    end
  end

  def last_order
    Order
      .select(:orders__o_id, :type, :o_status, :o_loc, :u_id, :orders__created_at)
      .join(:line_items, line_items__o_id: :orders__o_id)
      .join(:items, line_items__i_id: :items__o_id, line_items__i_id: @values[:i_id])
      .order(:o_id)
      .last
  end

  def is_on_some_order o_id
    return false if @values[:i_status] == Item::READY
    last = last_order
    errors.add("Error de carga", "Este item ya fue agregado a la orden actual con anterioridad.") if last.o_id == o_id
    errors.add("Error de carga", "Este item pertenece a la orden. #{last.o_id}") if last.o_id != o_id
    return true
  end

  def has_been_sold
    if @values[:i_status] == Item::SOLD
      errors.add("Item vendido anteriormente", "Este item ya fue vendido. Que hace aqui otra vez?")
      return true
    end
    return false
  end

  def has_been_void
    if @values[:i_status] == Item::VOID
      errors.add("Item anulado", "Este item fue Invalidado. No podes operar sobre el.")
      return true
    end
    return false
  end

  def is_returning
    if self.i_status == Item::RETURNING
      errors.add("Item en devolución", "Este item ya está en la devolución. No podes agregarlo nuevamente.")
      return true
    end
    return false
  end

  def has_not_been_sold
    if self.i_status != Item::SOLD
      errors.add(R18n.t.return.errors.invalid_status.to_s, R18n.t.return.errors.this_item_is_not_in_sold_status.to_s)
      return true
    end
    return false
  end

  def is_not_ready
    if @values[:i_status] != Item::READY
      errors.add("Item no listo", "Este item esta en un estado #{ConstantsTranslator.new(@values[:i_status]).t}. No podes operar sobre el.")
      return true
    end
    return false
  end

  def change_status_security_check status, o_id
    if @values[:i_status] == Item::VOID
      message = R18n.t.errors.modifying_status_of_void_item(@values[:i_id])
      log = ActionsLog.new.set(msg: message, u_id: User.new.current_user_id, l_id: User.new.current_location[:name], lvl: ActionsLog::ERROR, i_id: @values[:i_id])
      log.set(o_id: o_id) unless o_id == 0
      log.save
      raise SecurityError, message
    end
    if @values[:p_id].nil? and not @values[:i_status] == Item::NEW and not status == Item::VOID
      message = R18n.t.errors.modifying_status_of_nil_product_item(@values[:i_id])
      log = ActionsLog.new.set(msg: message, u_id: User.new.current_user_id, l_id: User.new.current_location[:name], lvl: ActionsLog::ERROR, i_id: @values[:i_id])
      log.set(o_id: o_id) unless o_id == 0
      log.save
      raise SecurityError, message
    end
  end

  def change_status status, o_id
    o_id = o_id.to_i
    change_status_security_check status, o_id
    @values[:i_status] = status
    save columns: [:p_id, :p_name, :i_price, :i_price_pro, :i_status, :i_loc]
    message = R18n.t.actions.changed_status(ConstantsTranslator.new(status).t)
    log = ActionsLog.new.set(msg: message, u_id: User.new.current_user_id, l_id: User.new.current_location[:name], lvl: ActionsLog::INFO, i_id: @values[:i_id])
    log.set(o_id: o_id) unless o_id == 0
    log.set(p_id: @values[:p_id]) unless @values[:p_id].nil?
    log.save

    product = Product[self.p_id]
    product.update_stocks.save unless product.nil?

    message
  end

  def i_loc= location
    @values[:i_loc] = location
  end

  def dissociate o_id=nil
    DB.transaction do
      message = R18n::t.product.item_removed
      ActionsLog.new.set(msg: message, u_id: User.new.current_user_id, l_id: User.new.current_location[:name], lvl: ActionsLog::NOTICE, i_id: @values[:i_id], p_id: @values[:p_id], o_id: o_id).save

      defaults = Item
                  .select{default(:p_id).as(p_id)}
                  .select_append{default(:p_name).as(p_name)}
                  .select_append{default(:i_price).as(i_price)}
                  .select_append{default(:i_price_pro).as(i_price_pro)}
                  .select_append{default(:i_status).as(i_status)}
                  .first
      @values[:p_id]        = defaults[:p_id]
      @values[:p_name]      = defaults[:p_name]
      @values[:i_price]     = defaults[:i_price]
      @values[:i_price_pro] = defaults[:i_price_pro]
      @values[:i_status]    = Item::PRINTED
      save validate: false
      self
    end
  end

  def print
    out     = "\n"
    out     += "#{self.class} #{sprintf("%x", self.object_id)}:\n"
    out     += "\ti_id:  #{self.i_id}\n"
    out     += "\tp_id:  #{self.p_id}\n"
    out     += "\tp_name:  #{self.p_name}\n"
    out     += self.i_price ? "\ti_price: #{sprintf("%0.2f", self.i_price)}\n" : "\ti_price: \n"
    out     += self.i_price_pro ? "\ti_price_pro: #{sprintf("%0.2f", self.i_price_pro)}\n" : "\ti_price_pro: \n"
    out     += "\ti_status: #{self.i_status}\n"
    out     += "\ti_loc: #{self.i_loc}\n"
    created = self.created_at ? Utils::local_datetime_format(self.created_at) : ""
    out     += "\tcreated: #{created}\n"
    puts out
  end

  def validate
    super

    validates_schema_types [:i_id, :i_id]
    validates_schema_types [:p_id, :p_id]
    validates_schema_types [:i_price, :i_price]
    validates_schema_types [:i_price_pro, :i_price_pro]
    validates_schema_types [:i_status, :i_status]
    validates_schema_types [:created_at, :created_at]

    validates_exact_length 12, :i_id, message: "Id inválido #{@values[:i_id]}"
    validates_presence [:p_name, :i_status], message: "No esta asignado"

    if i_status != Item::NEW && i_status != Item::PRINTED
      if p_id.class != Fixnum
        errors.add("p_id", "Debe ser numérico. #{p_id} (#{p_id.class}) dado" )
      else
        errors.add("p_id", "Debe ser positivo. #{p_id} dado" ) unless p_id > 0
      end
    end

    if (i_price.class != BigDecimal) && (i_price.class != Fixnum)
      errors.add("Precio", "Debe ser numérico. #{i_price} (#{i_price.class}) dado" )
    elsif i_price < 0
      num = i_price.class == BigDecimal ? i_price.round(3).to_s("F") :  i_price
      errors.add("Precio", "Debe ser positivo o cero. #{num} dado" )
    end

    if (i_price_pro.class != BigDecimal) && (i_price_pro.class != Fixnum)
      errors.add("Precio", "Debe ser numérico. #{i_price_pro} (#{i_price_pro.class}) dado" )
    elsif i_price_pro < 0
      num = i_price_pro.class == BigDecimal ? i_price_pro.round(3).to_s("F") :  i_price_pro
      errors.add("Precio", "Debe ser positivo o cero. #{num} dado" )
    end

  end


  def get_items
    Item
      .join(:products, [:p_id])
      .join(:categories, [:c_id])
      .order(:items__p_name)
  end

  def get_items_at_location location
    get_items
      .filter(i_loc: location)
  end

  def get_items_at_location_with_status location, status
    get_items_at_location(location)
      .filter(i_status: status.to_s)
  end

  def get_for_verification i_id, o_id
    i_id = i_id.to_s.strip
    item = Item.filter(i_status: Item::MUST_VERIFY, i_id: i_id).first
    if item.nil?
      item = Item[i_id]
      if item.nil?
        message = "No tengo ningun item con el id \"#{i_id}\""
        errors.add("Error general", message)
        return self
      end
      item_o_id = Item.select(:o_id).filter(i_id: i_id).join(:line_items, [:i_id]).first[:o_id]
      if item_o_id  == o_id
        message = "Este item ya esta en la orden actual"
        errors.add("Error leve", message)
      else
        if item.i_status == Item::ASSIGNED
          message = "Este item (#{item.i_id}) ya esta asignado a #{item.p_name}"
          errors.add("Error general", message)
        end
        if item.i_status == Item::VOID
          message = "Esta etiqueta fue anulada (#{item.i_id}). Tenias que haberla destruido"
          errors.add("Error general", message)
        end
        if item.i_status == Item::VERIFIED
          message = "Este item ya fue verificado con anterioridad."
          errors.add("Error de ingreso", message)
        elsif item.i_status != Item::MUST_VERIFY
          message = "Esta etiqueta esta en estado \"#{ConstantsTranslator.new(item.i_status).t}\". No podes usarla en esta orden"
          errors.add("Error general", message)
        end
      end
      if errors.count == 0
        message = "No podes utilizar el item #{label.i_id} en la orden actual por que esta en la orden #{item_o_id}"
        errors.add("Error general", message)
      end
      return self
    else
      return item
    end
  end

  def get_for_sale i_id, o_id
    i_id = i_id.to_s.strip
    item = Item.filter(i_status: Item::READY, i_loc: User.new.current_location[:name], i_id: i_id).first
    return item unless item.nil?
    return self if missing(i_id)
    update_from Item[i_id]

    return self if has_been_void
    return self if is_from_production
    return self if is_from_another_location
    return self if is_on_cart o_id
    return self if has_been_sold
    errors.add("Error inesperado", "Que hacemos?")
    return self
  end

  def get_for_transport i_id, o_id
    i_id = i_id.to_s.strip
    item = Item.filter(i_status: Item::READY, i_loc: User.new.current_location[:name], i_id: i_id).first
    return item unless item.nil?
    return self if missing(i_id)
    update_from Item[i_id]
    return self if has_been_void
    return self if is_from_another_location
    return self if has_been_sold # TODO: anulacion de venta
    return self if is_on_some_order o_id
    errors.add("Error inesperado", "Que hacemos?")
    return self
  end

  def get_for_removal i_id, o_id
    i_id = i_id.to_s.strip
    item = Item.filter(i_loc: User.new.current_location[:name], i_id: i_id).join(:line_items, [:i_id]).filter(o_id: o_id).first
    return item unless item.nil?
    return self if missing(i_id)
    update_from Item[i_id]
    return self if has_been_void
    return self if is_from_another_location
    return self if has_been_sold # TODO: anulacion de venta
    return self if is_on_some_order o_id
    errors.add("Error inesperado", "Que hacemos?")
    return self
  end

  def get_for_transmutation i_id
    i_id = i_id.to_s.strip
    item = Item.filter(i_status: Item::READY, i_id: i_id).first
    return item unless item.nil?
    return self if missing(i_id)
    update_from Item[i_id]
    return self if has_been_void
    return self if has_been_sold # TODO: anulacion de venta
    return self if is_not_ready
    errors.add("Error inesperado", "Que hacemos?")
    return self
  end

  def get_for_return i_id, return_id
    i_id = i_id.to_s.strip
    sale_id = SalesToReturn.filter(return: return_id).first[:sale]
    item = Item
            .filter(i_status: Item::SOLD, i_loc: User.new.current_location[:name], type: Order::SALE, i_id: i_id, o_id: sale_id)
            .join(:line_items, [:i_id])
            .join(:orders, [:o_id])
            .order(:orders__o_id)
            .last

    return item unless item.nil?
    return self if missing(i_id)
    item = Item
            .filter(i_id: i_id, type: Order::SALE)
            .join(:line_items, [:i_id])
            .join(:orders, [:o_id])
            .order(:orders__o_id)
            .last
    if item.nil?
      item = Item
              .filter(i_id: i_id)
              .join(:line_items, [:i_id])
              .join(:orders, [:o_id])
              .order(:orders__o_id)
              .last
    end
    update_from item
    return self if is_returning
    return self if has_not_been_sold
    return self if order_missmatch sale_id
    return self if has_been_void
    return self if is_from_production
    return self if is_from_another_location
    return self if is_on_cart return_id
    errors.add("Error inesperado", "Que hacemos?")
    return self
  end
end

