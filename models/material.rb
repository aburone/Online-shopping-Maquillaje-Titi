# coding: utf-8
require_relative 'bulk'

class Material < Sequel::Model(:materials)
  one_to_many :bulks, key: :m_id
  Material.nested_attributes :bulks

  many_to_one :MaterialCategory, key: :c_id
  many_to_many :products, left_key: :m_id, right_key: :product_id, join_table: :products_materials

  # def create_default
  #   begin
  #     m_id = Material.insert(m_name: R18n::t.material.default_name)
  #   rescue
  #     m_id = Material.filter(m_name: R18n::t.material.default_name).first.m_id
  #   end
  #   m_id
  # end

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
    wanted_keys = [ :m_name, :c_id ] # .gsub(',', '.')
    hash_values.select { |key, value| self[key.to_sym]=value if wanted_keys.include? key.to_sym unless value.nil?}
    validate
    self
  end

  def validate
    super
    errors.add(:name, 'cannot be empty or nil') if !m_name || m_name.empty?
    errors.add(:m_id, "must be numeric '#{m_id}' (#{m_id.class}) given") unless m_id.class == Fixnum
    errors.add(:m_id, "must be positive #{m_id} given") unless m_id.class == Fixnum && m_id > 0
  end

  def to_s
    @values[:m_qty] ||= 0
    out = "\n"
    out += "#{self.class} #{sprintf("%x", self.object_id)}:\n"
    out += "\tm_name:  #{@values[:m_name]}\n"
    out += "\tm_id:  #{@values[:m_id]}\n"
    out += "\tc_id:  #{@values[:c_id]}\n"
    out += "\tc_name: " + (@values[:c_name].nil? ? "\n" : @values[:c_name] + "\n")
    out += "\tm_qty: #{sprintf("%0.2f", @values[:m_qty])}\n"
    out += "\tm_price: #{m_price_as_string}\n"
    out += "\tcreated: #{Utils::local_datetime_format  @values[:created_at]}\n"
    out
  end

  def m_price_as_string
    if self[:m_price].nil?
      ret = 0
    else
      ret = self[:m_price].round(3)
      ret = ret.to_s("F") if ret.class == BigDecimal
    end
    ret
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
        .order(:m_name)
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
      Material.select_group(:materials__m_id, :m_name, :c_id, :c_name)
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


