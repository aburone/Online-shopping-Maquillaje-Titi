# coding: utf-8
require_relative 'bulk'

class Material < Sequel::Model(:materials)
  one_to_many :bulks, key: :m_id
  Material.nested_attributes :bulks

  many_to_one :MaterialCategory, key: :c_id
  many_to_many :products, left_key: :m_id, right_key: :product_id, join_table: :products_materials

  COLUMNS = [ :m_id, :c_id, :m_name, :m_notes, :created_at, :m_ideal_stock, :m_price ]

  def update_stocks
    stock = Material
      .select{sum(:b_qty).as(stock_store_1)}
      .left_join(:bulks, materials__m_id: :bulks__m_id, b_loc: Location::S1)
      .where(materials__m_id: @values[:m_id])
      .first[:stock_store_1]
    stock ||= 0
    @values[:stock_store_1] = BigDecimal.new stock
    stock = Material
      .select{sum(:b_qty).as(stock_store_2)}
      .left_join(:bulks, materials__m_id: :bulks__m_id, b_loc: Location::S2)
      .where(materials__m_id: @values[:m_id])
      .first[:stock_store_2]
    stock ||= 0
    @values[:stock_store_2] = BigDecimal.new stock
    stock = Material
      .select{sum(:b_qty).as(stock_warehouse_1)}
      .left_join(:bulks, materials__m_id: :bulks__m_id, b_loc: Location::W1)
      .where(materials__m_id: @values[:m_id])
      .first[:stock_warehouse_1]
    stock ||= 0
    @values[:stock_warehouse_1] = BigDecimal.new stock
    stock = Material
      .select{sum(:b_qty).as(stock_warehouse_2)}
      .left_join(:bulks, materials__m_id: :bulks__m_id, b_loc: Location::W2)
      .where(materials__m_id: @values[:m_id])
      .first[:stock_warehouse_2]
    stock ||= 0
    @values[:stock_warehouse_2] = BigDecimal.new stock
    update_stock_deviation
  end

  def update_stock_deviation
    ideal = @values[:m_ideal_stock]
    actual = @values[:m_qty].nil? ? BigDecimal.new(0) : @values[:m_qty]
    @values[:stock_deviation] = ideal - actual
    @values[:stock_deviation] *= -1
    @values[:stock_deviation_percentile] = @values[:stock_deviation] * 100 / (@values[:m_ideal_stock])
    @values[:stock_deviation_percentile] = BigDecimal.new(0) if @values[:stock_deviation_percentile].nan?
  end

  def stock_deviation_percentile
    @values[:stock_deviation_percentile]
  end

  def calculate_ideal_stock
    self.m_price = Material.new.get_price(self.m_id)
    p "#{@values[:m_name]} (#{@values[:m_id]}) #{Utils::money_format self.m_price, 6}"
    total_needed = BigDecimal.new(0)
    products = self.products
    products.each do |product|
      materials = product.materials
      materials.each do |p_material|
        needed = (product[:archived] or product[:end_of_life]) ? BigDecimal.new(0) : (p_material[:m_qty] * product.ideal_stock)
        p "  #{product.p_name} (#{product.p_id}): #{p_material[:m_qty].to_s("F")} x #{product.ideal_stock} = #{needed.to_s("F")}" if p_material.m_id == @values[:m_id]
        total_needed += needed if p_material.m_id == @values[:m_id]
      end
    end
    p "Partial needed: #{total_needed.to_s("F")}"
    products = Product.all
    products.each do |product|
      parts = product.parts
      parts.each do |product_part|
        materials = product_part.materials
        materials.each do |p_material|
          needed = (product[:archived] or product[:end_of_life]) ? BigDecimal.new(0) : p_material[:m_qty] * product_part[:part_qty] * product_part.ideal_stock 
          p "  #{product.p_name} (#{product.p_id}) -> #{product_part.p_name} (#{product_part.p_id}): #{p_material[:m_qty].to_s("F")} x #{product_part[:part_qty].to_s("F")} x #{product_part.ideal_stock} = #{needed.to_s("F")}" if p_material.m_id == @values[:m_id]
          total_needed += needed if p_material.m_id == @values[:m_id]
        end
      end
    end
    p "Total needed: #{total_needed.to_s("F")}"
    p ""
    @values[:m_ideal_stock] = total_needed * 2 # ideal for products is 3 months, but for materials is 6 months
    save columns: COLUMNS
    total_needed * 2
  end

  def create_default
    last_m_id = "ERROR"
    DB.transaction do
      material = Material.new
      material.save validate: false
      last_m_id = DB.fetch( "SELECT last_insert_id() AS m_id" ).first[:m_id]
      message = R18n.t.material.created
      ActionsLog.new.set(msg: message, u_id: User.new.current_user_id, l_id: User.new.current_location[:name], lvl: ActionsLog::INFO, m_id: last_m_id).save
    end
    last_m_id
  end


  def update_from_hash(hash_values)
    wanted_keys = [ :m_name, :m_notes, :c_id ]
    hash_values.select { |key, value| self[key.to_sym]=value if wanted_keys.include? key.to_sym unless value.nil?}

    numerical_keys = [ :m_ideal_stock, :m_price ]
    hash_values.select do |key, value|
      if numerical_keys.include? key.to_sym 
        unless value.nil? or (value.class == String and value.length == 0)
          if Utils::is_numeric? value.to_s.gsub(',', '.')
            self[key.to_sym] = Utils::as_number value
          end
        end
      end
    end

    validate
    self
  end

  def validate
    super
    errors.add(:Nombre, R18n.t.errors.presence) if !m_name || m_name.empty?
    errors.add(:m_id, R18n.t.errors.numeric_feedback(m_id, m_id.class) ) unless m_id.class == Fixnum
    errors.add(:m_id, R18n.t.errors.positive_feedback(m_id) ) unless m_id.class == Fixnum && m_id > 0
  end

  def to_s
    @values[:m_qty] ||= 0
    out = "\n"
    out += "#{self.class} #{sprintf("%x", self.object_id)}:\n"
    out += "\tm_name:  #{@values[:m_name]}\n"
    out += "\tm_notes:  #{@values[:m_notes]}\n"
    out += "\tm_id:  #{@values[:m_id]}\n"
    out += "\tc_id:  #{@values[:c_id]}\n"
    out += "\tc_name: " + (@values[:c_name].nil? ? "\n" : @values[:c_name] + "\n")
    out += "\tm_qty: #{sprintf("%0.2f", @values[:m_qty])}\n"
    out += "\tm_price: #{Utils::number_format self[:m_price], 3}\n"
    out += "\tm_ideal_stock: #{Utils::number_format self[:m_ideal_stock], 2}\n"
    out += "\tcreated: #{Utils::local_datetime_format  @values[:created_at]}\n"
    out
  end

  def m_price= price
    @values[:m_price] = price
  end

  def bulks warehouse_name
    begin
      Bulk.filter(m_id: @values[:m_id], b_loc: warehouse_name).order(:b_status, :created_at).all
    rescue Exception => @e
      p @e
      return []
    end
  end

  def bulks_global
    begin
      Bulk.filter(m_id: @values[:m_id]).order(:b_status, :created_at).all
    rescue Exception => @e
      p @e
      return []
    end
  end


  def products
    self.products_dataset.join(:categories, [:c_id]).select_append{:c_name}.all
  end


  def get_price m_id
    price = Bulk.select{max(:b_price).as(b_price)}.where(m_id: m_id.to_i).group(:m_id).first
    return price.nil? ? 0 : price[:b_price]
  end

  def get_list warehouse_name
    begin
      materials = base_query(warehouse_name)
        .order(:c_name, :m_name)
        .all
      materials.each { |mat| mat.m_price = Material.new.get_price(mat.m_id) }
      materials
    rescue Exception => @e
      p @e
      return []
    end
  end

  def get_by_id id, warehouse_name
    begin
      base_query(warehouse_name)
        .where(materials__m_id: id.to_i)
        .select_append{max(Material.new.get_price id.to_i).as(m_price)}
        .first
    rescue Exception => @e
      p @e
      return []
    end
  end

  private
    def base_query warehouse_name
      valid = [Bulk::NEW, Bulk::IN_USE, Bulk::VOID]
      Material.select_group(:materials__m_id, :m_name, :c_id, :c_name, :m_notes, :m_ideal_stock)
        .left_join(:bulks___b1, b1__m_id: :materials__m_id, b1__b_status: valid, b1__b_loc: warehouse_name)
        .join(:materials_categories, [:c_id])
        .select_append{sum(:b1__b_qty).as(m_qty)}
    end

end

# #################################################################################

class MaterialsCategory < Sequel::Model
  one_to_many :materials, key: :c_id
end

# #################################################################################


