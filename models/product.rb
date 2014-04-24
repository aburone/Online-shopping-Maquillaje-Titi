require 'sequel'
require 'json'
require_relative 'item'

class Product < Sequel::Model
  many_to_one :category, key: :c_id
  one_to_many :items, key: :p_id
  Product.nested_attributes :items
  many_to_many :materials , left_key: :product_id, right_key: :m_id, join_table: :products_materials
  many_to_many :products_parts , left_key: :p_id, right_key: :p_id, join_table: :products_parts


  ATTRIBUTES = [:p_id, :c_id, :p_name, :p_short_name, :br_name, :br_id, :packaging, :size, :color, :sku, :public_sku, :direct_ideal_stock, :indirect_ideal_stock, :ideal_stock, :on_request, :stock_deviation, :stock_warehouse_1, :stock_warehouse_2, :stock_store_1, :stock_store_2, :buy_cost, :parts_cost, :materials_cost, :sale_cost, :ideal_markup, :real_markup, :exact_price, :price, :price_pro, :published_price, :published, :archived, :tercerized, :end_of_life, :description, :notes, :img, :img_extra, :created_at, :price_updated_at]
  # same as ATTRIBUTES but with the neccesary table references for get_ functions
  COLUMNS = [:p_id, :c_id, :p_name, :p_short_name, :br_id, :packaging, :size, :color, :sku, :notes, :direct_ideal_stock, :indirect_ideal_stock, :ideal_stock, :stock_deviation, :stock_warehouse_1, :stock_warehouse_2, :stock_store_1, :stock_store_2, :buy_cost, :parts_cost, :materials_cost, :sale_cost, :ideal_markup, :real_markup, :exact_price, :price, :price_pro, :published_price, :tercerized, :published, :on_request, :archived, :end_of_life, :products__img, :img_extra, :products__created_at, :price_updated_at, :products__description, :brands__br_name]
  EXCLUDED_ATTRIBUTES_IN_DUPLICATION = [:p_id, :end_of_life, :archived, :published, :img, :img_extra, :sku, :public_sku, :stock_warehouse_1, :stock_warehouse_2, :stock_store_1, :stock_store_2, :stock_deviation, :created_at, :price_updated_at]

  STORE_ONLY_1 = "STORE_ONLY_1"
  STORE_ONLY_2 = "STORE_ONLY_2"
  STORE_ONLY_3 = "STORE_ONLY_3"
  ALL_LOCATIONS_1 = "ALL_LOCATIONS_1"
  ALL_LOCATIONS_2 = "ALL_LOCATIONS_2"
  ALL_LOCATIONS_3 = "ALL_LOCATIONS_3"
  DEVIATION_CALCULATION_MODES = [STORE_ONLY_1, STORE_ONLY_2, STORE_ONLY_3, ALL_LOCATIONS_1, ALL_LOCATIONS_2, ALL_LOCATIONS_3]

  @inventory = nil

  def get p_id
    return Product.new unless p_id.to_i > 0
    product = Product.select_group(:products__p_id, :products__p_name, :products__br_id, :products__description, :products__img, :c_id, :p_short_name, :packaging, :size, :color, :sku, :public_sku, :direct_ideal_stock, :indirect_ideal_stock, :ideal_stock, :on_request, :stock_deviation, :stock_store_1, :stock_store_2, :stock_warehouse_1, :stock_warehouse_2, :buy_cost, :parts_cost, :materials_cost, :sale_cost, :ideal_markup, :real_markup, :exact_price, :price, :price_pro, :published_price, :published, :archived, :tercerized, :end_of_life, :notes, :img_extra, :products__created_at, :price_updated_at)
                .filter(products__p_id: p_id.to_i)
                .left_join(:categories, [:c_id])
                .left_join(:brands, [:br_id])
                .select_append{:brands__br_name}
                .select_append{:categories__c_name}
                .group(:products__p_id, :products__p_name, :products__br_id, :products__description, :products__img, :c_id, :p_short_name, :packaging, :size, :color, :sku, :public_sku, :direct_ideal_stock, :indirect_ideal_stock, :ideal_stock, :on_request, :stock_deviation, :stock_store_1, :stock_store_2, :stock_warehouse_1, :stock_warehouse_2, :buy_cost, :parts_cost, :materials_cost, :sale_cost, :ideal_markup, :real_markup, :exact_price, :price, :price_pro, :published_price, :published, :archived, :tercerized, :end_of_life, :notes, :img_extra, :brands__br_name, :categories__c_name, :products__created_at, :price_updated_at)
                .first
    return Product.new if product.nil?

    product.update_costs
    product.recalculate_markups
    product.update_stocks
    product
  end

  def update_costs
    parts_cost
    materials_cost
    self
  end

  def materials_cost
    cost = BigDecimal.new 0, 4
    self.materials.map { |material| cost +=  material[:m_qty] * material[:m_price] }
    p "el costo de materiales retorno nil" if cost.nil?
    self.materials_cost = cost.round(2)
    cost.round(2)
  end

  def parts_cost
    cost = BigDecimal.new 0, 2
    self.parts.map { |part| cost += part.materials_cost }
    p "el costo de partes retorno nil" if cost.nil?
    cost = BigDecimal.new 0, 2 if cost.nil?
    self.parts_cost = cost
    cost
  end

  def recalculate_markups
    self[:real_markup] = self[:price] / self[:sale_cost] if self[:sale_cost] > 0
    self[:ideal_markup] = self[:real_markup] if self[:ideal_markup] == 0 and self[:real_markup] > 0
    self
  end

  def update_indirect_ideal_stock
    self.indirect_ideal_stock = BigDecimal.new(0)
    self.assemblies.each { |assembly| self.indirect_ideal_stock += assembly[:part_qty] * assembly.inventory(1).global.ideal unless assembly.archived}
    self.indirect_ideal_stock *= 2
    self.ideal_stock = self.direct_ideal_stock * 2 + self.indirect_ideal_stock
    self
  end

  def update_stocks
    self.stock_store_1 = BigDecimal.new Product
      .select{count(i_id).as(stock_store_1)}
      .left_join(:items, products__p_id: :items__p_id, i_status: Item::READY, i_loc: Location::S1)
      .where(products__p_id: @values[:p_id])
      .first[:stock_store_1]
    @values[:en_route_stock_store_1] = BigDecimal.new Product
      .select{count(i_id).as(en_route_stock_store_1)}
      .left_join(:items, products__p_id: :items__p_id, i_status: Item::MUST_VERIFY, i_loc: Location::S1)
      .where(products__p_id: @values[:p_id])
      .first[:en_route_stock_store_1]
    @values[:virtual_stock_store_1] = @values[:en_route_stock_store_1] + @values[:stock_store_1]
    self.stock_warehouse_1 = BigDecimal.new Product
      .select{count(i_id).as(stock_warehouse_1)}
      .left_join(:items, products__p_id: :items__p_id, i_status: Item::READY, i_loc: Location::W1)
      .where(products__p_id: @values[:p_id])
      .first[:stock_warehouse_1]
    self.stock_warehouse_2 = BigDecimal.new Product
      .select{count(i_id).as(stock_warehouse_2)}
      .left_join(:items, products__p_id: :items__p_id, i_status: Item::READY, i_loc: Location::W2)
      .where(products__p_id: @values[:p_id])
      .first[:stock_warehouse_2]

    self.stock_deviation = inventory(1).global.deviation
    archive_or_revive
    self
  end

  def inventory for_months = 1
    return @inventory unless @inventory.nil? or @inventory_months != for_months
    @inventory = OpenStruct.new
    @inventory_months = for_months
    store_1 = OpenStruct.new
    store_1.stock = BigDecimal.new self.stock_store_1, 2
    store_1.en_route = @values[:en_route_stock_store_1].nil? ? BigDecimal.new(0, 2) : BigDecimal.new(@values[:en_route_stock_store_1], 2)
    store_1.virtual =  BigDecimal.new(store_1.stock + store_1.en_route,)
    store_1.ideal = self.direct_ideal_stock * for_months
    store_1.deviation = store_1.stock - store_1.ideal
    store_1.deviation_percentile = store_1.deviation * 100 / store_1.ideal
    store_1.deviation_percentile = BigDecimal.new(0, 2) if store_1.deviation_percentile.nan? or store_1.deviation_percentile.infinite? or store_1.deviation_percentile.nil?
    store_1.v_deviation = BigDecimal.new(store_1.virtual - store_1.ideal, 2)
    store_1.v_deviation_percentile = store_1.v_deviation * 100 / store_1.ideal
    store_1.v_deviation_percentile = BigDecimal.new(0, 2) if store_1.v_deviation_percentile.nan? or store_1.v_deviation_percentile.infinite? or store_1.v_deviation_percentile.nil?

    warehouse_1 = OpenStruct.new
    warehouse_1.stock = BigDecimal.new self.stock_warehouse_1, 2
    warehouse_1.en_route = 0
    warehouse_1.virtual = warehouse_1.stock + warehouse_1.en_route

    warehouse_2 = OpenStruct.new
    warehouse_2.stock = BigDecimal.new self.stock_warehouse_2, 2
    warehouse_2.en_route = 0
    warehouse_2.virtual = warehouse_2.stock + warehouse_2.en_route

    warehouses = OpenStruct.new
    warehouses.stock = warehouse_1.stock + warehouse_2.stock
    warehouses.virtual =  warehouse_1.virtual + warehouse_2.virtual

    warehouses.ideal = self.direct_ideal_stock * for_months + self.indirect_ideal_stock * for_months
    warehouses.deviation = warehouses.stock - warehouses.ideal
    warehouses.deviation_percentile = warehouses.deviation * 100 / warehouses.ideal
    warehouses.deviation_percentile = BigDecimal.new(0, 2) if warehouses.deviation_percentile.nan? or warehouses.deviation_percentile.infinite? or warehouses.deviation_percentile.nil?
    warehouses.v_deviation = warehouses.virtual - warehouses.ideal
    warehouses.v_deviation_percentile = warehouses.v_deviation * 100 / warehouses.ideal
    warehouses.v_deviation_percentile = BigDecimal.new(0, 2) if warehouses.v_deviation_percentile.nan? or warehouses.v_deviation_percentile.infinite? or warehouses.v_deviation_percentile.nil?

    global = OpenStruct.new
    global.stock = warehouses.stock + store_1.stock
    global.en_route = store_1.en_route + warehouse_1.en_route + warehouse_2.en_route
    global.virtual = global.stock + global.en_route
    global.ideal = store_1.ideal + warehouses.ideal

    global.deviation = global.stock - global.ideal
    global.deviation_percentile = global.deviation * 100 / global.ideal
    global.deviation_percentile = BigDecimal.new(0, 2) if global.deviation_percentile.nan? or global.deviation_percentile.infinite? or global.deviation_percentile.nil?
    global.v_deviation = global.virtual - global.ideal
    global.v_deviation_percentile = global.v_deviation * 100 / global.ideal
    global.v_deviation_percentile = BigDecimal.new(0, 2) if global.v_deviation_percentile.nan? or global.v_deviation_percentile.infinite? or global.v_deviation_percentile.nil?

    @inventory.store_1 = store_1
    @inventory.warehouse_1 = warehouse_1
    @inventory.warehouse_2 = warehouse_2
    @inventory.warehouses = warehouses
    @inventory.global = global
    @inventory
  end

  def price_round exact_price
    price = exact_price
    frac = price.abs.modulo(1)
    if frac > 0
      price += frac >= 0.5 ? -frac + 1 : -frac + 0.5
      price += 0.5 if frac < 0.5 and price > 100
    end
    price
  end

  def price_mod mod, log=true
    mod = BigDecimal.new(mod.to_s.gsub(',', '.'), 15)
    if mod > 0
      start_price = self.exact_price.dup
      self.exact_price *= mod
      self.price = price_round self.exact_price
      self.price_pro = (self.price * 0.95).round 1
      update_costs
      if log
        message = "Precio ajustado *#{mod.to_s("F")} de $ #{start_price.to_s("F")} a $ #{self.price.to_s("F")}: #{self.p_name}"
        ActionsLog.new.set(msg: message, u_id: User.new.current_user_id, l_id: "GLOBAL", lvl: ActionsLog::NOTICE, p_id: self.p_id).save
      end
    end
    self
  end

  def materials
    condition = "product_id = #{self.p_id}"
    Material.join( ProductsMaterial.where{condition}, [:m_id]).all
  end

  def parts
    # https://github.com/jeremyevans/sequel/blob/master/doc/querying.rdoc#join-conditions
    return [] unless self[:p_id].to_i > 0
    condition = "product_id = #{self[:p_id]}"
    Product.join( ProductsPart.where{condition}, part_id: :products__p_id).all
  end

  def assemblies
    product_part =  ProductsPart
                      .select{Sequel.lit('product_id').as(p_id)}
                      .select_append{:part_qty}
                      .where(part_id: self.p_id)
                      .all
    assemblies = []
    product_part.each do |assy|
      assembly = Product.new.get(assy[:p_id])
      assembly[:part_id] = self.p_id
      assembly[:part_qty] = assy[:part_qty]
      assembly[:part_cost] = self.sale_cost * assy[:part_qty]
      assemblies << assembly
    end
    assemblies
  end

  def recalculate_sale_cost
    self[:sale_cost] = BigDecimal.new(@values[:buy_cost] + @values[:parts_cost] + @values[:materials_cost], 2)
    recalculate_markups
  end

  def materials_cost= cost
    self[:materials_cost] = cost
    recalculate_sale_cost
  end

  def parts_cost= cost
    self[:parts_cost] = cost
    recalculate_sale_cost
  end

  def buy_cost= cost
    self[:buy_cost] = cost
    recalculate_sale_cost
  end

  def sale_cost
    BigDecimal.new(@values[:buy_cost] + @values[:parts_cost] + @values[:materials_cost], 2)
  end

  def sku= sku
    sku = sku.to_s.gsub(/\n|\r|\t/, '').squeeze(" ").strip
    @values[:sku] = sku.empty? ? nil : sku
    self
  end

  def add_part part
    errors.add "Error de ingreso", "La cantidad de la parte a agregar no puede ser cero ni negativa" if part[:part_qty] <= 0
    return false if part[:part_qty] <= 0
    ProductsPart.unrestrict_primary_key
    ProductsPart.create(product_id: self[:p_id], part_id: part[:p_id], part_qty: part[:part_qty])
  end

  def remove_products_part part
    remove_part part
  end

  def remove_part part
    ProductsPart.filter(product_id: self[:p_id], part_id: part[:p_id]).first.delete
  end

  def update_part part
    if part[:part_qty] < 0
      errors.add "Error de ingreso", "La cantidad de la parte no puede ser negativa"
      return ProductsPart.filter(product_id: self[:p_id], part_id: part[:p_id]).first
    end
    if part[:part_qty] == 0
      remove_part part
      return true
    end
    prod_part =  ProductsPart.filter(product_id: self[:p_id], part_id: part[:p_id]).first
    prod_part[:part_qty] = part[:part_qty]
    prod_part.save
  end

  def add_material material
    errors.add "Error de ingreso", "La cantidad del material a agregar no puede ser cero ni negativa" if material[:m_qty] <= 0
    return false if material[:m_qty] <= 0
    ProductsMaterial.unrestrict_primary_key
    ProductsMaterial.create(product_id: self[:p_id], m_id: material[:m_id], m_qty: material[:m_qty])
  end

  def update_material material
    if material[:m_qty] < 0
      errors.add "Error de ingreso", "La cantidad del material no puede ser negativa"
      return ProductsMaterial.filter(product_id: self[:p_id], m_id: material[:m_id]).first
    end
    if material[:m_qty] == 0
      remove_material material
      return true
    end
    prod_mat =  ProductsMaterial.filter(product_id: self[:p_id], m_id: material[:m_id]).first
    prod_mat[:m_qty] = material[:m_qty]
    prod_mat.save
  end

  def duplicate
    dest_id = create_default
    dest = Product[dest_id]
    dest.update_from(self)
    dest[:public_sku] = rand
    dest.save
    self.parts.map { |part| dest.add_part part }
    self.materials.map { |material| dest.add_material material }
    dest
  end

  def update_from product
    columns_to_copy = ATTRIBUTES - EXCLUDED_ATTRIBUTES_IN_DUPLICATION
    columns_to_copy.each { |col| self[col] = product[col] }
    self
  end

  def create_default
    last_p_id = "ERROR"
    DB.transaction do
      product = Product.new
      product.save validate: false
      last_p_id = DB.fetch( "SELECT last_insert_id() AS p_id" ).first[:p_id]
      message = R18n.t.product.created
      ActionsLog.new.set(msg: message, u_id: User.new.current_user_id, l_id: User.new.current_location[:name], lvl: ActionsLog::INFO, p_id: last_p_id).save
    end
    last_p_id
  end

  def empty?
    return @values[:p_id].nil? ? true : false
  end

  def save (opts=OPTS)
    opts = opts.merge({columns: Product::ATTRIBUTES})
    self.end_of_life = false if self.archived
    self.price_pro = (self.price * 0.95).round 1

    begin
      super opts
      if self.p_name and not self.archived
        message = "Actualizancion de precio de todos los items de #{@values[:p_name]}"
        ActionsLog.new.set(msg: message, u_id: User.new.current_user_id, l_id: "GLOBAL", lvl: ActionsLog::NOTICE, p_id: @values[:p_id]).save
        DB.run "UPDATE items
        JOIN products using(p_id)
        SET items.i_price = products.price, items.i_price_pro = products.price_pro, items.p_name = products.p_name
        WHERE p_id = #{@values[:p_id]} AND i_status IN ( 'ASSIGNED', 'MUST_VERIFY', 'VERIFIED', 'READY' )"
      end
    rescue Sequel::UniqueConstraintViolation
      errors.add "SKU duplicado", "Ya existe un producto con ese sku"
    end
    self
  end

  def items
    condition = "p_id = #{self[:p_id]}"
    Item.select(:i_id, :items__p_id, :items__p_name, :i_price, :i_price_pro, :i_status, :i_loc, :items__created_at).join( Product.where{condition}, [:p_id]).all
  end

  def add_item label, o_id
    o_id = o_id.to_i
    if label.nil?
      message = R18n::t.errors.inexistent_label
      log = ActionsLog.new.set(msg: "#{message}", u_id: User.new.current_user_id, l_id: User.new.current_location[:name], lvl:  ActionsLog::ERROR)
      log.set(o_id: o_id) unless o_id == 0
      log.save
      errors.add "General", message
      return ""
    end
    if label.class != Label
      message = R18n::t.errors.this_is_not_a_label(label.class)
      log = ActionsLog.new.set(msg: "#{message}", u_id: User.new.current_user_id, l_id: User.new.current_location[:name], lvl:  ActionsLog::ERROR)
      log.set(o_id: o_id) unless o_id == 0
      log.save
      errors.add "General", message
      return ""
    end
    current_user_id = User.new.current_user_id
    label.p_id = @values[:p_id]
    label.p_name = @values[:p_name]
    label.i_status = Item::ASSIGNED
    label.i_price = @values[:price]
    label.i_price_pro = @values[:price_pro]
    begin
      label.save
      super label
      assigned_msg = R18n::t.label.assigned(label.i_id, @values[:p_name])
      log = ActionsLog.new.set(msg: assigned_msg, u_id: User.new.current_user_id, l_id: User.new.current_location[:name], lvl:  ActionsLog::INFO, i_id: label.i_id, p_id: @values[:p_id])
      log.set(o_id: o_id) unless o_id == 0
      log.save
      return assigned_msg
    rescue Sequel::ValidationFailed
      assigned_msg = label.errors.to_s
      log = ActionsLog.new.set(msg: assigned_msg, u_id: User.new.current_user_id, l_id: User.new.current_location[:name], lvl:  ActionsLog::ERROR, i_id: label.i_id, p_id: @values[:p_id])
      log.set(o_id: o_id) unless o_id == 0
      log.save
      return assigned_msg
    rescue => detail
      assigned_msg = detail.message
      log = ActionsLog.new.set(msg: assigned_msg, u_id: User.new.current_user_id, l_id: User.new.current_location[:name], lvl:  ActionsLog::ERROR, i_id: label.i_id, p_id: @values[:p_id])
      log.set(o_id: o_id) unless o_id == 0
      log.save
      return assigned_msg
    end
  end

  def remove_item item
    defaults = Item
                .select(:i_id)
                .select_append{default(:p_id).as(p_id)}
                .select_append{default(:p_name).as(p_name)}
                .select_append{default(:i_price).as(i_price)}
                .select_append{default(:i_price_pro).as(i_price_pro)}
                .select_append{default(:i_status).as(i_status)}
                .first
    item.p_id = defaults[:p_id]
    item.p_name = defaults[:p_name]
    item.i_price = defaults[:i_price]
    item.i_price_pro = defaults[:i_price_pro]
    item.i_status = Item::PRINTED
    item.save validate: false
    assigned_msg = R18n::t.product.item_removed
    ActionsLog.new.set(msg: assigned_msg, u_id: User.new.current_user_id, l_id: User.new.current_location[:name], lvl: ActionsLog::INFO, i_id: item.i_id, p_id: @values[:p_id]).save
  end

  def whith_obj obj
    product = Product.new
    COLUMNS.map { |col| product[col.to_sym] = obj[col.to_sym]}
    product
  end

  def print
    out = "\n"
    out += "#{self.class} #{sprintf("%x", self.object_id)}:\n"
    out += "\tp_id:               #{@values[:p_id]}\n"
    out += "\tc_id:               #{@values[:c_id]}\n"
    out += "\tbr_id:              #{@values[:br_id]}\n"

    out += "\tp_name:             #{@values[:p_name]}\n"
    out += "\tp_short_name:       #{@values[:p_short_name]}\n"
    out += "\tbr_name:            #{@values[:br_name]}\n"
    out += "\tpackaging:          #{@values[:packaging]}\n"
    out += "\tsize:               #{@values[:size]}\n"
    out += "\tcolor:              #{@values[:color]}\n"
    out += "\tsku:                #{@values[:sku]}\n"
    out += "\tpublic_sku:                #{@values[:public_sku]}\n"

    out += "\td_ideal_stock:        #{Utils::number_format @values[:direct_ideal_stock], 0}\n"
    out += "\ti_ideal_stock:        #{Utils::number_format @values[:indirect_ideal_stock], 0}\n"
    out += "\tideal_stock:        #{Utils::number_format @values[:ideal_stock], 0}\n"
    out += "\tstock_deviation:    #{Utils::number_format @values[:stock_deviation], 0}\n"
    out += "\tstock_deviation_%:  #{Utils::number_format @values[:stock_deviation_percentile], 2}\n"
    out += "\tstock_warehouse_1:  #{Utils::number_format @values[:stock_warehouse_1], 0}\n"
    out += "\tstock_warehouse_2:  #{Utils::number_format @values[:stock_warehouse_2], 0}\n"
    out += "\tstock_store_1:      #{Utils::number_format @values[:stock_store_1], 0}\n"
    out += "\ten_route_stock_store_1: #{Utils::number_format @values[:en_route_stock_store_1], 0}\n"
    out += "\tvirtual_stock_store_1:      #{Utils::number_format @values[:virtual_stock_store_1], 0}\n"
    out += "\tbuy_cost:           #{Utils::number_format @values[:buy_cost], 2}\n"
    out += "\tparts_cost:         #{Utils::number_format @values[:parts_cost], 2}\n"
    out += "\tmaterials_cost:     #{Utils::number_format @values[:materials_cost], 2}\n"
    out += "\tsale_cost:          #{Utils::number_format @values[:sale_cost], 2}\n"
    out += "\tideal_markup:       #{Utils::number_format @values[:ideal_markup], 3}\n"
    out += "\treal_markup:        #{Utils::number_format @values[:real_markup], 3}\n"
    out += "\texact_price:        #{Utils::number_format @values[:exact_price], 5}\n"
    out += "\tprice:              #{Utils::number_format @values[:price], 5}\n"
    out += "\tprice_pro:          #{Utils::number_format @values[:price_pro], 2}\n"

    out += "\tpublished:          #{@values[:published]}\n"
    out += "\tpublished_price:    #{@values[:published_price]}\n"
    out += "\ttercerized:         #{@values[:tercerized]}\n"
    out += "\tend_of_life:        #{@values[:end_of_life]}\n"
    out += "\tarchived:           #{@values[:archived]}\n"
    out += "\tdescription:        #{@values[:description]}\n"
    out += "\tnotes:              #{@values[:notes]}\n"
    out += "\timg:                #{@values[:img]}\n"
    out += "\timg_extra:          #{@values[:img_extra]}\n"
    out += "\tnotes:              #{@values[:notes]}\n"
    echo out
  end

  def set_life_point life_point
    case life_point
      when "live"
        self.end_of_life = false
        self.archived = false
      when "end_of_life"
        self.end_of_life = true
        self.archived = false
      when "archived"
        archive
    end
    self
  end

  def status
    status = R18n.t.product.fields.live.to_s
    status = R18n.t.product.fields.on_request.to_s if self.on_request
    status = R18n.t.product.fields.end_of_life.to_s if self.end_of_life
    status = R18n.t.product.fields.archived.to_s if self.archived
    status
  end

  def get_by_sku sku
    sku.to_s.gsub(/\n|\r|\t/, '').squeeze(" ").strip
    product = Product.filter(sku: sku).first
    return Product.new if product.nil?
    product
  end

  def get_list
    Product
      .select_group(*Product::COLUMNS, :categories__c_name)
      .join(:categories, [:c_id])
      .join(:brands, [:br_id])
      .select_append{ Sequel.case( {{Sequel.lit('real_markup / ideal_markup') => nil} => 0}, Sequel.lit('(real_markup * 100 / ideal_markup) - 100') ).as(markup_deviation_percentile)}
      .where(archived: 0)
  end

  def get_saleable_at_location location
    Product
      .select_group(:products__p_id, :products__p_name, :buy_cost, :sale_cost, :ideal_markup, :real_markup, :price, :price_pro, :direct_ideal_stock, :indirect_ideal_stock, :ideal_stock, :stock_deviation, :products__img, :products__c_id, :products__br_id, :sku)
      .where(archived: 0)
      .left_join(:categories, [:c_id])
      .left_join(:items, products__p_id: :items__p_id, i_status: "READY", i_loc: location.to_s)
      .join(:brands, [:br_id])
      .select_append{:brands__br_name}
      .select_append{:categories__c_name}
      .select_append{ Sequel.case( {{Sequel.lit('real_markup / ideal_markup') => nil} => 0}, Sequel.lit('(real_markup * 100 / ideal_markup) - 100') ).as(markup_deviation_percentile)}
      .select_append{count(i_id).as(qty)}
      .group(:products__p_id, :products__p_name, :buy_cost, :sale_cost, :ideal_markup, :real_markup, :price, :price_pro, :direct_ideal_stock, :indirect_ideal_stock, :ideal_stock, :stock_deviation, :products__img, :products__c_id, :categories__c_name, :products__br_id, :brands__br_name, :sku)
  end

  def get_saleable_at_all_locations products = nil
    products = get_list.order(:categories__c_name, :products__p_name) if products.nil?
    new_products = []
    products.map do |product|
      product.update_stocks
      new_products << product
    end
    new_products
  end

  def validate
    super
    validates_schema_types [:p_id, :p_id]
    validates_schema_types [:c_id, :c_id]
    validates_schema_types [:p_name, :p_name]
    validates_schema_types [:p_short_name, :p_short_name]
    validates_schema_types [:br_name, :br_name]
    validates_schema_types [:br_id, :br_id]
    validates_schema_types [:packaging, :packaging]
    validates_schema_types [:size, :size]
    validates_schema_types [:color, :color]
    validates_schema_types [:sku, :sku]
    validates_schema_types [:public_sku, :public_sku]
    validates_schema_types [:buy_cost, :buy_cost]
    validates_schema_types [:sale_cost, :sale_cost]
    validates_schema_types [:ideal_markup, :ideal_markup]
    validates_schema_types [:real_markup, :real_markup]
    validates_schema_types [:exact_price, :exact_price]
    validates_schema_types [:price, :price]
    validates_schema_types [:price_pro, :price_pro]
    validates_schema_types [:published_price, :published_price]
    validates_schema_types [:published, :published]
    validates_schema_types [:archived, :archived]
    validates_schema_types [:description, :description]
    validates_schema_types [:notes, :notes]
    validates_schema_types [:img, :img]
    validates_schema_types [:img_extra, :img_extra]

    validates_presence [:p_name, :p_short_name, :br_name, :br_id, :stock_store_1, :stock_store_2, :stock_warehouse_1, :stock_warehouse_2, :exact_price, :price]

    errors.add("El costo de compra", "no puede ser cero" ) if @values[:buy_cost] + @values[:sale_cost] == 0

    errors.add("El markup ideal", "no puede ser cero" ) if @values[:ideal_markup] == 0
    if @values[:real_markup] == 0
      errors.add("El markup real", "no puede ser cero. Producto #{@values[:p_id]}" )
      puts self
    end

    errors.add("El precio exacto", "no puede ser cero" ) if @values[:exact_price] == 0
    errors.add("El precio", "no puede ser cero" ) if @values[:price] == 0
  end



  def update_from_hash(hash_values)
    raise ArgumentError, t.errors.nil_params if hash_values.nil?
    numerical_keys = [ :direct_ideal_stock, :indirect_ideal_stock, :stock_store_1, :stock_store_2, :stock_warehouse_1, :stock_warehouse_2, :stock_deviation, :buy_cost, :sale_cost, :ideal_markup, :real_markup, :exact_price, :price, :price_pro]
    hash_values.select do |key, value|
      if numerical_keys.include? key.to_sym
        unless value.nil? or (value.class == String and value.length == 0)
          if Utils::is_numeric? value.to_s.gsub(',', '.')
            self[key.to_sym] = Utils::as_number value
          end
        end
      end
    end
    cast

    alpha_keys = [ :c_id, :p_short_name, :packaging, :size, :color, :sku, :public_sku, :description, :notes, :img, :img_extra ]
    hash_values.select { |key, value| eval("self.#{key}=value.to_s") if alpha_keys.include? key.to_sym unless value.nil?}

    checkbox_keys = [:published_price, :published, :on_request]
    checkbox_keys.each { |key| self[key.to_sym] = hash_values[key].nil? ? 0 : 1 }

    true_false_keys = [:tercerized]
    true_false_keys.each { |key| self[key.to_sym] = hash_values[key] == "true" ? 1 : 0 }

    set_life_point hash_values[:life_point]

    unless hash_values[:brand].nil?
      brand_json = JSON.parse(hash_values[:brand])
      brand_keys = [ :br_id, :br_name ]
      brand_keys.select { |key, value| self[key.to_sym]=brand_json[key.to_s] unless brand_json[key.to_s].nil?}
    end

    self[:p_name] = ""
    [self[:p_short_name], self[:br_name], self[:packaging], self[:size], self[:color], self[:public_sku] ].map { |part| self[:p_name] += " " + part unless part.nil?}
    cast
    self
  end

  private
    def cast
      @values[:exact_price] = @values[:exact_price] ? BigDecimal.new(@values[:exact_price], 0) : BigDecimal.new(0, 2)
      @values[:price] = @values[:price] ? BigDecimal.new(@values[:price], 0) : BigDecimal.new(0, 2)
      @values[:price_pro] = @values[:price_pro] ? BigDecimal.new(@values[:price_pro], 0) : BigDecimal.new(0, 2)
      @values[:direct_ideal_stock] = @values[:direct_ideal_stock] ? BigDecimal.new(@values[:direct_ideal_stock], 0) : BigDecimal.new(0, 2)
      @values[:indirect_ideal_stock] = @values[:direct_ideal_stock] ? BigDecimal.new(@values[:indirect_ideal_stock], 0) : BigDecimal.new(0, 2)
      @values[:ideal_stock] = @values[:direct_ideal_stock] + @values[:indirect_ideal_stock]
      @values[:stock_deviation] = @values[:stock_deviation] ? BigDecimal.new(@values[:stock_deviation], 0) : BigDecimal.new(0, 2)
      @values[:stock_deviation_percentile] = @values[:stock_deviation_percentile] ? BigDecimal.new(@values[:stock_deviation_percentile], 0) : BigDecimal.new(0, 2)
      @values[:stock_store_1] = @values[:stock_store_1] ? BigDecimal.new(@values[:stock_store_1], 0) : BigDecimal.new(0, 2)
      @values[:stock_store_2] = @values[:stock_store_2] ? BigDecimal.new(@values[:stock_store_2], 0) : BigDecimal.new(0, 2)
      @values[:stock_warehouse_1] = @values[:stock_warehouse_1] ? BigDecimal.new(@values[:stock_warehouse_1], 0) : BigDecimal.new(0, 2)
      @values[:stock_warehouse_2] = @values[:stock_warehouse_2] ? BigDecimal.new(@values[:stock_warehouse_2], 0) : BigDecimal.new(0, 2)
      self.buy_cost = self.buy_cost ? BigDecimal.new(self.buy_cost, 0) : BigDecimal.new(0, 2)
      @values[:sale_cost] = @values[:sale_cost] ? BigDecimal.new(@values[:sale_cost], 0) : BigDecimal.new(0, 2)
      @values[:ideal_markup] = @values[:ideal_markup] ? BigDecimal.new(@values[:ideal_markup], 0) : BigDecimal.new(0, 2)
      @values[:real_markup] = @values[:real_markup] ? BigDecimal.new(@values[:real_markup], 0) : BigDecimal.new(0, 2)
    end

    def archive_or_revive
      return archive if must_be_archived
      return revive if must_be_revived
      self
    end

    def must_be_archived
      self.end_of_life and inventory(1).global.virtual == 0
    end

    def must_be_revived
      self.archived and inventory(1).global.virtual > 0
    end

    def archive
      if inventory(1).global.virtual == 0
        self.end_of_life = false
        self.archived =  true
        message = "Archivado por agotar existencias"
        ActionsLog.new.set(msg: message, u_id: User.new.current_user_id, l_id: User.new.current_location[:name], lvl: ActionsLog::NOTICE, p_id: self.p_id).save
        save
      else
        self.end_of_life = true
        self.archived = false
        save
        message = 'No se puede archivar un producto hasta que su stock sea 0. Seteado a "Fin de vida"'
        errors.add "Error de ingreso", message
        ActionsLog.new.set(msg: message, u_id: User.new.current_user_id, l_id: User.new.current_location[:name], lvl: ActionsLog::WARN, p_id: self.p_id).save
      end
      self
    end

    def revive
      if inventory(1).global.virtual > 0
        self.end_of_life = true
        self.archived =  false
        message = 'Producto seteado en estado "Fin de vida" por tener stock'
        ActionsLog.new.set(msg: message, u_id: User.new.current_user_id, l_id: User.new.current_location[:name], lvl: ActionsLog::WARN, p_id: self.p_id).save
        save
      end
      self
    end

end
