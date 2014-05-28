class Product < Sequel::Model
  many_to_one :category, key: :c_id
  one_to_many :items, key: :p_id
  Product.nested_attributes :items
  many_to_many :materials , left_key: :product_id, right_key: :m_id, join_table: :products_materials
  many_to_many :products_parts , left_key: :p_id, right_key: :p_id, join_table: :products_parts
  many_to_many :distributors , left_key: :p_id, right_key: :d_id, join_table: :products_to_distributors

  ATTRIBUTES = [:p_id, :c_id, :p_name, :p_short_name, :br_name, :br_id, :packaging, :size, :color, :sku, :public_sku, :direct_ideal_stock, :indirect_ideal_stock, :ideal_stock, :on_request, :stock_deviation, :stock_warehouse_1, :stock_warehouse_2, :stock_store_1, :stock_store_2, :buy_cost, :parts_cost, :materials_cost, :sale_cost, :ideal_markup, :real_markup, :exact_price, :price, :price_pro, :published_price, :published, :archived, :tercerized, :end_of_life, :description, :notes, :img, :img_extra, :created_at, :price_updated_at]
  # same as ATTRIBUTES but with the neccesary table references for get_ functions
  COLUMNS = [:p_id, :c_id, :p_name, :p_short_name, :br_id, :packaging, :size, :color, :sku, :public_sku, :notes, :direct_ideal_stock, :indirect_ideal_stock, :ideal_stock, :stock_deviation, :stock_warehouse_1, :stock_warehouse_2, :stock_store_1, :stock_store_2, :buy_cost, :parts_cost, :materials_cost, :sale_cost, :ideal_markup, :real_markup, :exact_price, :price, :price_pro, :published_price, :tercerized, :published, :on_request, :archived, :end_of_life, :products__img, :img_extra, :products__created_at, :products__price_updated_at, :products__description, :brands__br_name]
  EXCLUDED_ATTRIBUTES_IN_DUPLICATION = [:p_id, :end_of_life, :archived, :published, :img, :img_extra, :sku, :public_sku, :stock_warehouse_1, :stock_warehouse_2, :stock_store_1, :stock_store_2, :stock_deviation, :created_at, :price_updated_at]


  def update_ideal_stock
    self.indirect_ideal_stock = BigDecimal.new(0)
# p ""
    self.assemblies.each do |assembly|
# ap assembly[:part_qty]
# ap assembly.inventory(1).global.ideal
      self.indirect_ideal_stock += assembly[:part_qty] * assembly.inventory(1).global.ideal unless assembly.archived
    end
# ap self.indirect_ideal_stock

    self.indirect_ideal_stock *= 2
    self.ideal_stock = self.direct_ideal_stock * 2 + self.indirect_ideal_stock
    self
  end

  def distributors
    return [] unless self.p_id.to_i > 0
    distributors = Distributor
                    .select_group(*Distributor::COLUMNS, *ProductDistributor::COLUMNS)
                    .join(:products_to_distributors, distributors__d_id: :products_to_distributors__d_id, products_to_distributors__p_id: self.p_id)
                    .order(:products_to_distributors__ptd_id)
    distributors
  end


  def create_default
    last_p_id = "ERROR"
    previous = Product.where(p_short_name: "NEW").first
    return previous.p_id unless previous.nil?
    DB.transaction do
      product = Product.new
      product[:public_sku] = rand
      product[:sku] = product[:public_sku]
      if product.errors.count > 0
        raise product.errors.to_a.flatten.join(": ")
      end
      product.save validate: false
      last_p_id = DB.fetch( "SELECT last_insert_id() AS p_id" ).first[:p_id]
      message = R18n.t.product.created
      ActionsLog.new.set(msg: message, u_id: User.new.current_user_id, l_id: User.new.current_location[:name], lvl: ActionsLog::INFO, p_id: last_p_id).save
    end
    last_p_id
  end

  def duplicate
    dest_id = create_default
    dest = Product[dest_id]
    dest.update_from(self)
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

  def save (opts=OPTS)
    opts = opts.merge({columns: Product::ATTRIBUTES})
    self.end_of_life = false if self.archived

    begin
      super opts
      if self.p_name and not self.archived
        message = "Actualizando todos los items de #{self.p_name}"
        ActionsLog.new.set(msg: message, u_id: User.new.current_user_id, l_id: "GLOBAL", lvl: ActionsLog::NOTICE, p_id: self.p_id).save
        DB.run "UPDATE items
        JOIN products using(p_id)
        SET items.i_price = products.price, items.i_price_pro = products.price_pro, items.p_name = products.p_name
        WHERE p_id = #{self.p_id} AND i_status IN ( 'ASSIGNED', 'MUST_VERIFY', 'VERIFIED', 'READY' )"
      end
    rescue Sequel::UniqueConstraintViolation => e
      errors.add "Error de duplicacion", e.message
    end
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

  def get p_id
    return Product.new unless p_id.to_i > 0
    product = Product.select_group(*Product::COLUMNS, :brands__br_name, :categories__c_name)
                .filter(products__p_id: p_id.to_i)
                .left_join(:categories, [:c_id])
                .left_join(:brands, [:br_id])
                .first
    return Product.new if product.nil?
    product.br_name = product[:br_name]
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
    cost = BigDecimal.new 0, 6
    self.materials.map { |material| cost +=  material[:m_qty] * material[:m_price] }
    p "el costo de materiales retorno nil" if cost.nil?
    self.materials_cost = cost.round(3)
    cost.round(3)
  end
  def parts_cost
    cost = BigDecimal.new 0, 2
    self.parts.map { |part| cost += part.materials_cost }
    p "el costo de partes retorno nil" if cost.nil?
    cost = BigDecimal.new 0, 2 if cost.nil?
    self.parts_cost = cost
    cost
  end


  def parts
    # https://github.com/jeremyevans/sequel/blob/master/doc/querying.rdoc#join-conditions
    return [] unless self[:p_id].to_i > 0
    condition = "product_id = #{self[:p_id]}"
    Product.join( ProductsPart.where{condition}, part_id: :products__p_id).all
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


  def materials
    condition = "product_id = #{self.p_id}"
    Material.join( ProductsMaterial.where{condition}, [:m_id]).order(:m_name).all
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
    label.i_price = self.price
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

  def get_by_sku sku
    sku.to_s.gsub(/\n|\r|\t/, '').squeeze(" ").strip
    product = Product.filter(sku: sku).first
    product ||= Product.new
    product
  end

  def get_all
    Product
      .select_group(*Product::COLUMNS, :categories__c_name)
      .join(:categories, [:c_id])
      .join(:brands, [:br_id])
      .select_append{ Sequel.case( {{Sequel.lit('real_markup / ideal_markup') => nil} => 0}, Sequel.lit('(real_markup * 100 / ideal_markup) - 100') ).as(markup_deviation_percentile)}
      .order(:c_name, :p_name)
  end

  def get_all_but_archived
    get_all
      .where(archived: 0)
  end

  def get_live
    get_all_but_archived
      .where(end_of_life: 0)
  end

  def get_saleable_at_location location
    Product
      .select_group(:products__p_id, :products__p_name, :buy_cost, :sale_cost, :ideal_markup, :real_markup, :price, :price_pro, :direct_ideal_stock, :indirect_ideal_stock, :ideal_stock, :stock_deviation, :stock_store_1, :stock_warehouse_1, :stock_warehouse_2, :products__img, :products__c_id, :products__br_id, :sku)
      .where(archived: 0)
      .left_join(:categories, [:c_id])
      .left_join(:items, products__p_id: :items__p_id, i_status: "READY", i_loc: location.to_s)
      .join(:brands, [:br_id])
      .select_append{:brands__br_name}
      .select_append{:categories__c_name}
      .select_append{ Sequel.case( {{Sequel.lit('real_markup / ideal_markup') => nil} => 0}, Sequel.lit('(real_markup * 100 / ideal_markup) - 100') ).as(markup_deviation_percentile)}
      .select_append{count(i_id).as(qty)}
      .group(:products__p_id, :products__p_name, :buy_cost, :sale_cost, :ideal_markup, :real_markup, :price, :price_pro, :direct_ideal_stock, :indirect_ideal_stock, :ideal_stock, :stock_deviation, :stock_store_1, :stock_warehouse_1, :stock_warehouse_2, :products__img, :products__c_id, :categories__c_name, :products__br_id, :brands__br_name, :sku)
  end

  def get_saleable_at_all_locations products = nil
    products = get_all_but_archived.order(:categories__c_name, :products__p_name) if products.nil?
    new_products = []
    products.map do |product|
      product.update_stocks
      new_products << product
    end
    new_products
  end

end
