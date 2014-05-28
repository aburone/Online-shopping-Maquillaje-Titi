require 'sequel'
require 'json'
require_relative 'item'

class Product < Sequel::Model

  STORE_ONLY_1 = "STORE_ONLY_1"
  STORE_ONLY_2 = "STORE_ONLY_2"
  STORE_ONLY_3 = "STORE_ONLY_3"
  ALL_LOCATIONS_1 = "ALL_LOCATIONS_1"
  ALL_LOCATIONS_2 = "ALL_LOCATIONS_2"
  ALL_LOCATIONS_3 = "ALL_LOCATIONS_3"
  DEVIATION_CALCULATION_MODES = [STORE_ONLY_1, STORE_ONLY_2, STORE_ONLY_3, ALL_LOCATIONS_1, ALL_LOCATIONS_2, ALL_LOCATIONS_3]

  @inventory = nil

  require_relative 'product_sql.rb'


  def perform
    # TODO: raise errors as warning message
    begin
      message = "Recalculando producto #{self.p_id}: #{self.p_name}"
      self.update_costs
      self.recalculate_markups
      self.update_stocks
      self.update_ideal_stock
      self.save validate: false
      ActionsLog.new.set(msg: message, u_id: User.new.current_user_id, l_id: Location::GLOBAL, lvl: ActionsLog::INFO, p_id: self.p_id).save
      self.validate
      if self.errors.count > 0
        message = "Error recalculando producto #{self.p_id} #{self.p_name}: #{self.errors.to_a.flatten.join(" ")}"
        ActionsLog.new.set(msg: message[0..254], u_id: User.new.current_user_id, l_id: Location::GLOBAL, lvl: ActionsLog::ERROR, p_id: self.p_id).save
      end
    rescue => detail
      message = "Error critico: #{detail.message} #{$@}"
      ActionsLog.new.set(msg: message[0..254], u_id: User.new.current_user_id, l_id: Location::GLOBAL, lvl: ActionsLog::ERROR).save
    end
  end

  def name
    self.p_name
  end

  def price= price
    price = price > 100 ? price.round : price.round(1)
    self[:price] = BigDecimal.new(price, 1)
    self.price_pro = (self.price * 0.95).round(1)
  end

  def price
    self[:price]
  end

  def buy_cost_mod mod
    mod = BigDecimal.new(mod.to_s.gsub(',', '.'), 15)
    if mod > 0
      self[:old_buy_cost] = self.buy_cost.dup
      self.buy_cost *= mod
      self[:new_buy_cost] = self.buy_cost
      recalculate_markups
    end
    self
  end

  def price_mod mod
    mod = BigDecimal.new(mod.to_s.gsub(',', '.'), 15)
    if mod > 0
      self[:old_price] = self.price.dup
      self.exact_price *= mod
      self.price = self.exact_price
      self[:new_price] = self.price
      recalculate_markups
    end
    self
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

  def empty?
    return @values[:p_id].nil? ? true : false
  end

  def set_life_phase life_phase
    return self if life_phase.nil?
    case life_phase.to_sym
      when :active
        self.end_of_life = false
        self.archived = false
      when :end_of_life
        self.end_of_life = true
        self.archived = false
      when :archived
        archive
    end
    self
  end

  def life_phase
    return :archived if self.archived
    return :end_of_life if self.end_of_life
    return :active
  end

  def status
    status = R18n.t.product.fields.life_cicle.active.to_s
    status = R18n.t.product.fields.on_request.to_s if self.on_request
    status = R18n.t.product.fields.life_cicle.end_of_life.to_s if self.end_of_life
    status = R18n.t.product.fields.life_cicle.archived.to_s if self.archived
    status
  end

  def recalculate_markups
    self[:real_markup] = self[:price] / self[:sale_cost] if self[:sale_cost] > 0
    self[:ideal_markup] = self[:real_markup] if self[:ideal_markup] == 0 and self[:real_markup] > 0
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

    validates_presence [:p_name, :p_short_name, :stock_store_1, :stock_store_2, :stock_warehouse_1, :stock_warehouse_2, :exact_price, :price]

    errors.add("La marca", "No puede estar vacia" ) if self[:br_id].nil?
    errors.add("El costo de compra", "no puede ser cero" ) if self[:buy_cost] + self[:sale_cost] == 0 unless self[:buy_cost].nil? || self[:sale_cost].nil?
    errors.add("El markup ideal", "no puede ser cero" ) if self[:ideal_markup] == 0
    errors.add("El markup real", "no puede ser cero." ) if self[:real_markup] == 0
    errors.add("El precio exacto", "no puede ser cero" ) if self[:exact_price] == 0
    errors.add("El precio", "no puede ser cero" ) if self.price == 0
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

    set_life_phase hash_values[:life_phase]

    unless hash_values[:brand].nil?
      brand_json = JSON.parse(hash_values[:brand])
      brand_keys = [ :br_id, :br_name ]
      brand_keys.select { |key, value| self[key.to_sym]=brand_json[key.to_s] unless brand_json[key.to_s].nil?}
    end

    self[:p_name] = ""
    [self[:p_short_name], self[:br_name], self[:packaging], self[:size], self[:color], self[:public_sku] ].map  { |part| self[:p_name] += " " + part unless part.nil?}
    cast
    self
  end

  private
    def cast
      @values[:exact_price] = @values[:exact_price] ? BigDecimal.new(@values[:exact_price], 0) : BigDecimal.new(0, 2)
      self.price = @values[:price] ? BigDecimal.new(@values[:price], 0) : BigDecimal.new(0, 2)
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
