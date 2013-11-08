require 'sequel'
require_relative 'item'

class Product < Sequel::Model
  many_to_one :category, key: :c_id
  one_to_many :items, key: :p_id
  Product.nested_attributes :items
  many_to_many :materials , left_key: :product_id, right_key: :m_id, join_table: :products_materials
  one_to_many :products_parts , left_key: :p_id, right_key: :p_id, join_table: :products_parts


  def empty?
    return @values[:p_id].nil? ? true : false
  end

  def get_rand
    max_pos = Product.count(:p_id)
    rnd = rand(max_pos)
    Product.limit(1, rnd).first
  end

  def cost
    parts_cost + materials_cost
  end

  def parts
    # https://github.com/jeremyevans/sequel/blob/master/doc/querying.rdoc#join-conditions
    condition = "product_id = #{self[:p_id]}"
    Product.join( ProductsPart.where{condition}, part_id: :products__p_id).all
  end

  def parts_cost
    parts_cost = 0
    self.parts.map { |part| parts_cost += part.materials_cost }
    parts_cost
  end

  def materials
    condition = "product_id = #{self[:p_id]}"
    materials = Material.join( ProductsMaterial.where{condition}, [:m_id])
    .all
    materials.each { |mat| mat.m_price = Material.new.get_price(mat.m_id) }
    materials
  end

  def materials_cost
    cost = 0
    self.materials.map { |material| cost +=  material[:m_qty] * material[:m_price] }
    cost
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
    product.p_id = obj[:p_id]
    product.c_id = obj[:c_id]
    product.p_name = obj[:p_name]
    product.br_name = obj[:br_name]
    product.brand_id = obj[:brand_id]
    product.packaging = obj[:packaging]
    product.stock_store_1 = obj[:stock_store_1]
    product.ideal_stock = obj[:ideal_stock]
    product.stock_warehouse_1 = obj[:stock_warehouse_1]
    product.stock_warehouse_2 = obj[:stock_warehouse_2]
    product.cost = obj[:cost]
    product.markup = obj[:markup]
    product.price = obj[:price]
    product.price_pro = obj[:price_pro]
    product.price_is_published = obj[:price_is_published]
    product.is_published = obj[:is_published]
    product.can_be_sold = obj[:can_be_sold]
    product.description = obj[:description]
    product.notes = obj[:notes]
    product.img = obj[:img]
    product.img_extra = obj[:img_extra]
    product
  end

  def to_s
    out = "\n"
    out += "#{self.class} #{sprintf("%x", self.object_id)}:\n"
    out += "\tp_id:               #{@values[:p_id]}\n"
    out += "\tc_id:               #{@values[:c_id]}\n"
    out += "\tp_name:             #{@values[:p_name]}\n"
    out += "\tbr_name:            #{@values[:br_name]}\n"
    out += "\tbr_id:              #{@values[:br_id]}\n"
    out += "\tpackaging:          #{@values[:packaging]}\n"
    out += "\tstock_store_1:      #{@values[:stock_store_1]}\n"
    out += "\tideal_stock:        #{@values[:ideal_stock]}\n"
    out += "\tstock_warehouse_1:  #{@values[:stock_warehouse_1]}\n"
    out += "\tstock_warehouse_2:  #{@values[:stock_warehouse_2]}\n"
    out += "\tcost:               #{@values[:cost]}\n"
    out += "\tmarkup:             #{@values[:markup]}\n"
    out += "\tprice:              #{@values[:price]}\n"
    out += "\tprice_pro:          #{@values[:price_pro]}\n"
    out += "\tprice_is_published: #{@values[:price_is_published]}\n"
    out += "\tis_published:       #{@values[:is_published]}\n"
    out += "\tcan_be_sold:        #{@values[:can_be_sold]}\n"
    out += "\tdescription:        #{@values[:description]}\n"
    out += "\tnotes:              #{@values[:notes]}\n"
    out += "\timg:                #{@values[:img]}\n"
    out += "\timg_extra:          #{@values[:img_extra]}\n"
    out
  end


  def get_list
    Product
      .select_group(:products__p_id, :products__p_name, :price, :price_pro, :ideal_stock, :products__img, :c_name)
      .join(:categories, [:c_id])
      .join(:brands, [:br_id])
      .select_append{:brands__br_name}
      .where(can_be_sold: 1)
  end
 
  def get_saleable
    Product
      .select_group(:products__p_id, :products__p_name, :price, :price_pro, :ideal_stock, :products__img, :c_name)
      .select_append{count(i_id).as(qty)}
      .filter(:can_be_sold)
      .left_join(:categories, [:c_id])
      .left_join(:items, products__p_id: :items__p_id, i_status: "READY")
      .join(:brands, [:br_id])
      .select_append{:brands__br_name}
      .group(:products__p_id, :products__p_name, :price, :price_pro, :ideal_stock, :products__img, :c_name, :br_name)
  end

  def get_saleable_at_location location
    Product
      .select_group(:products__p_id, :products__p_name, :price, :price_pro, :ideal_stock, :products__img, :c_name)
      .select_append{count(i_id).as(qty)}
      .filter(:can_be_sold)
      .left_join(:categories, [:c_id])
      .left_join(:items, products__p_id: :items__p_id, i_status: "READY", i_loc: location.to_s)
      .join(:brands, [:br_id])
      .select_append{:brands__br_name}
      .group(:products__p_id, :products__p_name, :price, :price_pro, :ideal_stock, :products__img, :c_name, :br_name)
  end

end

