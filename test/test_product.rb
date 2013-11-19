require_relative 'prerequisites'

class ProductTest < Test::Unit::TestCase

  def setup
  end

  def test_get_rand
    p = Product.new.get_rand
    assert_equal(Product, p.class)
  end

  # def test_decode
  #   require 'htmlentities'
  #   coder = HTMLEntities.new
  #   p = Product[528]
  #   assert_equal("Liquido corporal, colores básicos", p.p_name)
  # end

  # def test_decode_all
  #   require 'htmlentities'
  #   coder = HTMLEntities.new
  #   prods = Product.all
  #   prods.each do |p|
  #     p.p_name = coder.decode p.p_name
  #     p.description = coder.decode p.description
  #     p.notes = coder.decode p.notes
  #     p.brand = coder.decode p.brand
  #     p.save
  #   end
  # end

  def test_should_get_items
    p = Product[5]
    items = p.items
    items.each { |i| assert_equal(Item, i.class) }
  end

  def test_should_get_parts_with_id_and_qty
    p = Product[192]
    p.parts.each do |part|
      assert(part[:part_id])
      assert(part[:part_qty])
    end
  end

  def test_should_get_prod_materials_with_qty
    p = Product[194]
    p.materials.each do |mat|
      assert(mat[:m_qty])
    end
  end

  # def test_should_get_full_relatinship
    # product = Product[193]
    # # Label.new.save validate: false
    # # label = Label.new.get_rand
    # # label.assign_to product

    # p "Main Product"
    # puts product

    # p "Items"
    # items = product.items
    # items.each { |i| puts i}

    # p "Parts"
    # parts = product.parts
    # puts parts
    # p "Materials"
    # puts product.materials

    # p "First Part and it's Materials"
    # part = parts.first
    # puts part
    # materials = part.materials
    # puts materials
    # p "First part, first material, bulk"
    # material = materials.first
    # puts material
    # bulks = material.bulks Location::W1
    # bulks.each{ |bulk| puts bulk}
    
    # p "42"
    # puts Material.new.get_by_id 42

  # end

  def test_should_add_label_to_product
    DB.transaction(rollback: :always) do
      label = get_printed_label
      product = Product.new.get_rand
      before = product.items.count
      assigned_msg = product.add_item(label, nil)
      item = Item[label.i_id]
      assert_equal(Item::ASSIGNED, item.i_status)
      assert_equal(product.p_id, item.p_id)
      assert_equal(product.price, item.i_price)
      assert_equal(product.price_pro, item.i_price_pro)
      assert_equal assigned_msg, R18n::t.label.assigned(item.i_id, product.p_name)
      after = product.items.count
      assert_equal before+1, after
    end 
  end

  def test_should_remove_label_from_product
    product = Product.new.get_rand
    step1, step2, step3 = 0
    DB.transaction(rollback: :always) do
      label = get_printed_label
      step1 = product.items.count
      product.add_item label, nil
      step2 = product.items.count
      product.items.each do |item|
        product.remove_item item
      end
    end 
    step3 = product.items.count
    assert_equal step1+1, step2
    assert_equal step2-1, step3
    assert_equal step1, step3
  end

  def test_should_get_materials_cost
    product = Product[2]
    cost = 0
    product.materials.map { |material| cost +=  material[:m_qty] * material[:m_price] }
    assert_equal product.materials_cost, cost
  end

  def test_should_get_parts_cost
    product = Product[193]
    cost = 0
    product.parts.map { |part| cost += part.materials_cost }
    assert_equal product.parts_cost, cost
  end

  def test_cost_should_be_the_sum_of_parts_plus_materials
    product = Product[193]
    assert_equal product.cost, product.materials_cost + product.parts_cost

    product = Product[2]
    assert_equal product.cost, product.materials_cost + product.parts_cost
  end
end
