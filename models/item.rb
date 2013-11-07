require 'sequel'
require_relative 'order'

class Item < Sequel::Model
  many_to_one :product, key: :p_id
  many_to_many :orders, class: :Order, join_table: :line_items, left_key: :i_id, right_key: :o_id

  NEW="NEW"
  PRINTED="PRINTED"
  ASSIGNED="ASSIGNED"
  MUST_VERIFY="MUST_VERIFY"
  VERIFIED="VERIFIED"
  READY="READY"
  VOID="VOID"
  ON_CART="ON_CART"
  SOLD="SOLD"

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
    self
  end

  def current_sale_order
    Order
      .select(:orders__o_id, :type, :o_status, :o_loc, :u_id, :orders__created_at)
      .join(:line_items, line_items__o_id: :orders__o_id, orders__type: Order::SALE)
      .join(:items, line_items__i_id: :items__o_id, line_items__i_id: @values[:i_id])
      .first
  end

  def missing i_id
    if Item[i_id].nil?
      errors.add("Item invalido", "No tengo ningun item con el id #{i_id}") 
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

  def is_on_cart o_id
    return false unless @values[:i_status] == Item::ON_CART
    order = current_sale_order
    if o_id == current_sale_order.o_id
      errors.add("Error de carga", "Este item ya fue agragado a la orden actual con anterioridad.") 
      return true
    else
      errors.add("Item en otra venta en curso", "Este item pertenece a la orden #{order.o_id}. Que haces agregandolo a esta orden??") 
      return true
    end
  end

  def is_on_my_sale
    if @values[:i_status] == Item::ON_CART
      errors.add("Item vendido anteriormente", "Este item ya fue vendido. Que hace en el local otra vez?") 
      return true
    end
    return false
  end

  def has_been_sold 
    if @values[:i_status] == Item::SOLD
      errors.add("Item vendido anteriormente", "Este item ya fue vendido. Que hace en el local otra vez?") 
      return true
    end
    return false
  end

  def has_been_void 
    p "void"
    if @values[:i_status] == Item::VOID
      errors.add("Item anulado", "Este item fue Invalidado. No podes venderlo.") 
      return true
    end
    return false
  end

  def get_rand
    max_pos = Item.filter(i_status: Item::ASSIGNED).count(:i_id)
    if max_pos > 0
      rnd = rand(max_pos)
      return Item.filter(i_status: Item::ASSIGNED).limit(1, rnd).first
    else
      raise "No items available"
    end
  end


  def change_status status, o_id
    o_id = o_id.to_i
    if @values[:i_status] == Item::VOID
      message = R18n.t.errors.modifying_status_of_void_item(@values[:i_id])
      log = ActionsLog.new.set(msg: message, u_id: User.new.current_user_id, l_id: User.new.current_location[:name], lvl: ActionsLog::ERROR, i_id: @values[:i_id])
      log.set(o_id: o_id) unless o_id == 0
      log.save
      raise message
    end
    @values[:i_status] = status
    # @values[:i_loc] = Location::UNDEFINED if status == Item::VOID
    save columns: [:p_id, :p_name, :i_price, :i_price_pro, :i_status, :i_loc]
    message = R18n.t.actions.changed_status(ConstantsTranslator.new(status).t)
    log = ActionsLog.new.set(msg: message, u_id: User.new.current_user_id, l_id: User.new.current_location[:name], lvl: ActionsLog::INFO, i_id: @values[:i_id])
    log.set(o_id: o_id) unless o_id == 0
    log.set(p_id: @values[:p_id]) unless @values[:i_id].nil?
    log.save
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
      @values[:p_id] = defaults[:p_id]
      @values[:p_name] = defaults[:p_name]
      @values[:i_price] = defaults[:i_price]
      @values[:i_price_pro] = defaults[:i_price_pro]
      @values[:i_status] = Item::PRINTED
      save validate: false
      self
    end
  end

  def to_s
    out = "\n"
    out += "#{self.class} #{sprintf("%x", self.object_id)}:\n"
    out += "\ti_id:  #{@values[:i_id]}\n"
    out += "\tp_id:  #{@values[:p_id]}\n"
    out += "\tp_name:  #{@values[:p_name]}\n"
    out += @values[:i_price] ? "\ti_price: #{sprintf("%0.2f", @values[:i_price])}\n" : "\ti_price: \n"
    out += @values[:i_price_pro] ? "\ti_price_pro: #{sprintf("%0.2f", @values[:i_price_pro])}\n" : "\ti_price_pro: \n"
    out += "\ti_status: #{@values[:i_status]}\n"
    out += "\ti_loc: #{@values[:i_loc]}\n"
    created = @values[:created_at] ? Utils::local_datetime_format(@values[:created_at]) : ""
    out += "\tcreated: #{created}\n"
    out
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


  def get_list
    Item
      .join(:products, [:p_id])
      .join(:categories, [:c_id])
      .order(:items__p_name)
  end

  def get_list_at_location location
    Item
      .join(:products, [:p_id])
      .join(:categories, [:c_id])
      .order(:items__p_name)
      .filter(i_loc: location)
  end

  def get_in_location_with_status location, status
    get_list_at_location(location)
      .filter(i_status: status.to_s)
  end

  def get_unverified_by_id i_id, o_id
    i_id = i_id.to_s.strip
    item = Item.filter(i_status: Item::MUST_VERIFY, i_id: i_id).first
    if item.nil?
      item = Item[i_id]
      if item.nil?
        message = "No tengo ningun item con el id #{i_id}"
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
          errors.add("Error de ingredo", message)
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
    p i_id
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

end

