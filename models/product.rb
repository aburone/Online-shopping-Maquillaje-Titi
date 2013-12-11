require 'sequel'
require 'json'
require_relative 'item'

class Product < Sequel::Model
  many_to_one :category, key: :c_id
  one_to_many :items, key: :p_id
  Product.nested_attributes :items
  many_to_many :materials , left_key: :product_id, right_key: :m_id, join_table: :products_materials
  one_to_many :products_parts , left_key: :p_id, right_key: :p_id, join_table: :products_parts

  COLUMNS = [:p_id, :c_id, :p_name, :p_short_name, :br_name, :br_id, :packaging, :size, :color, :sku, :ideal_stock, :stock_store_1, :stock_store_2, :stock_warehouse_1, :stock_warehouse_2, :buy_cost, :parts_cost, :materials_cost, :sale_cost, :ideal_markup, :real_markup, :exact_price, :price, :price_pro, :published_price, :published, :archived, :description, :notes, :img, :img_extra]
  def empty?
    return @values[:p_id].nil? ? true : false
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

  def to_s
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

    out += "\tideal_stock:        #{@values[:ideal_stock]}\n"
    out += "\tstock_store_1:      #{@values[:stock_store_1]}\n"
    out += "\tstock_store_2:      #{@values[:stock_store_2]}\n"
    out += "\tstock_warehouse_1:  #{@values[:stock_warehouse_1]}\n"
    out += "\tstock_warehouse_2:  #{@values[:stock_warehouse_2]}\n"
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
    out += "\tarchived:           #{@values[:archived]}\n"
    out += "\tdescription:        #{@values[:description]}\n"
    out += "\tnotes:              #{@values[:notes]}\n"
    out += "\timg:                #{@values[:img]}\n"
    out += "\timg_extra:          #{@values[:img_extra]}\n"
    out += "\tnotes:              #{@values[:notes]}\n"
    out
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


  def parts
    # https://github.com/jeremyevans/sequel/blob/master/doc/querying.rdoc#join-conditions
    condition = "product_id = #{self[:p_id]}"
    Product.join( ProductsPart.where{condition}, part_id: :products__p_id).all
  end

  def materials
    condition = "product_id = #{self[:p_id]}"
    materials = Material.join( ProductsMaterial.where{condition}, [:m_id])
    .all
    materials.each { |mat| mat.m_price = Material.new.get_price(mat.m_id) }
    materials
  end

  def update_stocks
    @values[:stock_store_1] = Product
      .select{count(i_id).as(stock_store_1)}
      .left_join(:items, products__p_id: :items__p_id, i_status: "READY", i_loc: Location::S1)
      .where(products__p_id: @values[:p_id])
      .first[:stock_store_1]
    @values[:stock_store_2] = Product
      .select{count(i_id).as(stock_store_2)}
      .left_join(:items, products__p_id: :items__p_id, i_status: "READY", i_loc: Location::S2)
      .where(products__p_id: @values[:p_id])
      .first[:stock_store_2]
    @values[:stock_warehouse_1] = Product
      .select{count(i_id).as(stock_warehouse_1)}
      .left_join(:items, products__p_id: :items__p_id, i_status: "READY", i_loc: Location::W1)
      .where(products__p_id: @values[:p_id])
      .first[:stock_warehouse_1]
    @values[:stock_warehouse_2] = Product
      .select{count(i_id).as(stock_warehouse_2)}
      .left_join(:items, products__p_id: :items__p_id, i_status: "READY", i_loc: Location::W2)
      .where(products__p_id: @values[:p_id])
      .first[:stock_warehouse_2]
  end

  def update_markups
    @values[:real_markup] = @values[:price] / @values[:sale_cost] if @values[:sale_cost] > 0 
    @values[:ideal_markup] = @values[:real_markup] if @values[:ideal_markup] == 0 and @values[:real_markup] > 0
  end

  def update_costs
    @values[:parts_cost] = parts_cost
    @values[:materials_cost] = materials_cost
    @values[:sale_cost] = sale_cost
  end

  def parts_cost
    cost = 0
    self.parts.map { |part| cost += part.materials_cost }
    p "el costo de partes retorno nil" if cost.nil?
    cost
  end

  def materials_cost
    cost = 0
    self.materials.map { |material| cost +=  material[:m_qty] * material[:m_price] }
    p "el costo de materiales retorno nil" if cost.nil?
    cost
  end

  def sale_cost
    BigDecimal.new(@values[:buy_cost] + @values[:parts_cost] + @values[:materials_cost], 2)
  end

  def price_mod mod
    can_update = true
    can_update = false if mod <= 0 or mod == 1
    can_update = false if mod > 1 and mod < 1.01
    can_update = false if @values[:br_name] == "Mila Marzi"
    can_update = false if @values[:archived]

    if can_update
      start_price = @values[:exact_price].dup
      @values[:exact_price] *= mod
      @values[:price] = @values[:exact_price].dup
      frac = @values[:price].abs.modulo(1)
      if frac > 0 
        @values[:price] += frac >= 0.5 ? -frac + 1 : -frac + 0.5 
        @values[:price] += 0.5 if frac < 0.5 and @values[:price] > 100
      end
      update_markups
      message = "Precio ajustado de $ #{start_price.to_s("F")} a $ #{@values[:price].to_s("F")}: #{@values[:p_name]}"
      ActionsLog.new.set(msg: message, u_id: User.new.current_user_id, l_id: "GLOBAL", lvl: ActionsLog::NOTICE, p_id: @values[:p_id]).save
    end
  end

  def get p_id
    product = Product.select_group(:products__p_id, :products__p_name, :products__br_id, :products__description, :products__img, :c_id, :p_short_name, :br_id, :packaging, :size, :color, :sku, :ideal_stock, :stock_store_1, :stock_store_2, :stock_warehouse_1, :stock_warehouse_2, :buy_cost, :parts_cost, :materials_cost, :sale_cost, :ideal_markup, :real_markup, :exact_price, :price, :price_pro, :published_price, :published, :archived, :notes, :img_extra)
                .filter(products__p_id: p_id.to_i)
                .left_join(:categories, [:c_id])
                .left_join(:brands, [:br_id])
                .select_append{:brands__br_name}
                .select_append{:categories__c_name}
                .group(:products__p_id, :products__p_name, :products__br_id, :products__description, :products__img, :c_id, :p_short_name, :br_id, :packaging, :size, :color, :sku, :ideal_stock, :stock_store_1, :stock_store_2, :stock_warehouse_1, :stock_warehouse_2, :buy_cost, :parts_cost, :materials_cost, :sale_cost, :ideal_markup, :real_markup, :exact_price, :price, :price_pro, :published_price, :published, :archived, :notes, :img_extra, :brands__br_name, :categories__c_name)
                .first
    return Product.new if product.nil?
    product.update_stocks
    product.update_costs
    product.update_markups
    product
  end

  def get_list
    Product
      .select_group(:products__p_id, :products__p_name, :products__br_id, :products__description, :products__img, :c_id, :p_short_name, :br_id, :packaging, :size, :color, :sku, :ideal_stock, :stock_store_1, :stock_store_2, :stock_warehouse_1, :stock_warehouse_2, :buy_cost, :parts_cost, :materials_cost, :sale_cost, :ideal_markup, :real_markup, :exact_price, :price, :price_pro, :published_price, :published, :archived, :notes, :img_extra)
      .join(:categories, [:c_id])
      .join(:brands, [:br_id])
      .select_append{:brands__br_name}
      .select_append{:categories__c_name}
      .group(:products__p_id, :products__p_name, :products__br_id, :products__description, :products__img, :c_id, :p_short_name, :br_id, :packaging, :size, :color, :sku, :ideal_stock, :stock_store_1, :stock_store_2, :stock_warehouse_1, :stock_warehouse_2, :buy_cost, :parts_cost, :materials_cost, :sale_cost, :ideal_markup, :real_markup, :exact_price, :price, :price_pro, :published_price, :published, :archived, :notes, :img_extra, :brands__br_name, :categories__c_name)
      .where(archived: 0)
  end
 
  def get_saleable
    Product
      .select_group(:products__p_id, :products__p_name, :products__br_id, :products__description, :products__img, :c_id, :p_short_name, :br_id, :packaging, :size, :color, :sku, :ideal_stock, :stock_store_1, :stock_store_2, :stock_warehouse_1, :stock_warehouse_2, :buy_cost, :parts_cost, :materials_cost, :sale_cost, :ideal_markup, :real_markup, :exact_price, :price, :price_pro, :published_price, :published, :archived, :notes, :img_extra)
      .select_append{count(i_id).as(qty)}
      .join(:categories, [:c_id])
      .join(:brands, [:br_id])
      .join(:items, products__p_id: :items__p_id, i_status: "READY")
      .select_append{:brands__br_name}
      .group(:products__p_id, :products__p_name, :buy_cost, :parts_cost, :materials_cost, :sale_cost, :ideal_markup, :real_markup, :price, :price_pro, :ideal_stock, :products__img, :products__c_id, :c_name, :products__br_id, :br_name)
      .where(archived: 0)
  end

  def get_saleable_at_location location
    Product
      .select_group(:products__p_id, :products__p_name, :buy_cost, :sale_cost, :ideal_markup, :real_markup, :price, :price_pro, :ideal_stock, :products__img, :products__c_id, :c_name, :products__br_id)
      .where(archived: 0)
      .left_join(:categories, [:c_id])
      .left_join(:items, products__p_id: :items__p_id, i_status: "READY", i_loc: location.to_s)
      .join(:brands, [:br_id])
      .select_append{:brands__br_name}
      .select_append{count(i_id).as(qty)}
      .group(:products__p_id, :products__p_name, :buy_cost, :sale_cost, :ideal_markup, :real_markup, :price, :price_pro, :ideal_stock, :products__img, :products__c_id, :c_name, :products__br_id, :br_name)
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
    validates_schema_types [:ideal_stock, :ideal_stock]
    validates_schema_types [:stock_store_1, :stock_store_1]
    validates_schema_types [:stock_store_2, :stock_store_2]
    validates_schema_types [:stock_warehouse_1, :stock_warehouse_1]
    validates_schema_types [:stock_warehouse_2, :stock_warehouse_2]
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

    errors.add("El costo", "no puede ser cero" ) if @values[:buy_cost] + @values[:sale_cost] == 0

    errors.add("El markup ideal", "no puede ser cero" ) if @values[:ideal_markup] == 0
    if @values[:real_markup] == 0
      errors.add("El markup real", "no puede ser cero" ) 
      puts self
    end

    errors.add("El precio exacto", "no puede ser cero" ) if @values[:exact_price] == 0
    errors.add("El precio", "no puede ser cero" ) if @values[:price] == 0
  end



  def update_from_hash(hash_values)
    raise ArgumentError, t.errors.nil_params if hash_values.nil?
    numerical_keys = [ :ideal_stock, :stock_store_1, :stock_store_2, :stock_warehouse_1, :stock_warehouse_2, :buy_cost, :sale_cost, :ideal_markup, :real_markup, :exact_price, :price, :price_pro ]
    hash_values.select do |key, value|
      if numerical_keys.include? key.to_sym 
        unless value.nil? or (value.class == String and value.length == 0)
          if Utils::is_numeric? value.to_s.gsub(',', '.')
            # p "IN: #{key} #{value}, out: #{value.to_s.gsub(',', '.')}, nil: #{value.nil?}, class: #{value.class}, inspect: #{value.inspect}, Numeric: #{Utils::is_numeric? value.to_s.gsub(',', '.')}"
            self[key.to_sym] = Utils::as_number value
            # p "res: #{self[key.to_sym]}"
          else
            # p "#{key}: #{value.to_s.gsub(',', '.')} is not numeric"
          end
        else
          # p "#{key}: #{value} is nil"
        end
      else
        # p "#{key}: #{value} is not a numerical_key"
      end
    end
    cast

    alpha_keys = [ :c_id, :p_short_name, :packaging, :size, :color, :sku, :archived, :description, :notes, :img, :img_extra ]
    hash_values.select { |key, value| self[key.to_sym]=value.to_s if alpha_keys.include? key.to_sym unless value.nil?}

    checkbox_keys = [:published_price, :published]
    checkbox_keys.each { |key| self[key.to_sym] = hash_values[key].nil? ? 0 : 1 }

    unless hash_values[:brand].nil?
      brand_json = JSON.parse(hash_values[:brand])
      brand_keys = [ :br_id, :br_name ]
      brand_keys.select { |key, value| self[key.to_sym]=brand_json[key.to_s] unless brand_json[key.to_s].nil?}
    end

    self[:p_name] = ""
    [self[:p_short_name], self[:br_name], self[:packaging], self[:size], self[:color], self[:sku]].map { |part| self[:p_name] += " " + part unless part.nil?}
    cast
    self
  end

  private
    def cast
      self[:exact_price] = BigDecimal.new self[:exact_price], 5 if self[:exact_price]
      self[:price] = BigDecimal.new self[:price], 2 if self[:price]
      self[:price_pro] = BigDecimal.new self[:price_pro], 2 if self[:price_pro]
      self[:ideal_stock] = BigDecimal.new self[:ideal_stock], 0 if self[:ideal_stock]
      self[:stock_store_1] = BigDecimal.new self[:stock_store_1], 0 if self[:stock_store_1]
      self[:stock_store_2] = BigDecimal.new self[:stock_store_2], 0 if self[:stock_store_2]
      self[:stock_warehouse_1] = BigDecimal.new self[:stock_warehouse_1], 0 if self[:stock_warehouse_1]
      self[:stock_warehouse_2] = BigDecimal.new self[:stock_warehouse_2], 0 if self[:stock_warehouse_2]
      self[:buy_cost] = BigDecimal.new self[:buy_cost], 2 if self[:buy_cost]
      self[:sale_cost] = BigDecimal.new self[:sale_cost], 2 if self[:sale_cost]
      self[:ideal_markup] = BigDecimal.new self[:ideal_markup], 3 if self[:ideal_markup]
      self[:real_markup] = BigDecimal.new self[:real_markup], 3 if self[:real_markup]
    end
end

