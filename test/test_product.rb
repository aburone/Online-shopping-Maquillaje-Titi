require_relative 'prerequisites'

class ProductTest < Test::Unit::TestCase

  def setup
    @valid = Product.new
    @valid.sale_cost = BigDecimal.new 10
    @valid.price = BigDecimal.new 20
    @valid.exact_price = BigDecimal.new 19.54, 5
    @valid.update_markups
    @valid.p_name = "ProductTest @valid"
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
    product = Product.new.get 193
    assert_equal product.sale_cost, product.materials_cost + product.parts_cost

    product = Product.new.get 2
    assert_equal product.sale_cost, product.materials_cost + product.parts_cost
  end

  def test_mod_price_should_ignore_zero
    expected_price = @valid.price
    @valid.price_mod 0
    assert_equal expected_price, @valid.price
  end

  def test_mod_price_should_ignore_one
    expected_price = @valid.price
    @valid.price_mod 1
    assert_equal expected_price, @valid.price
  end

  def test_mod_price_should_include_mila_marzi
    @valid.br_name = "Mila Marzi"
    mod = 1.1
    expected = 21.5 # 21.494
    expected_price = BigDecimal.new("#{expected}", 2)
    @valid.price_mod mod
    assert_equal expected_price.to_s("F") , @valid.price.to_s("F")
  end

  def test_mod_price_should_include_archived
    DB.transaction(rollback: :always) do
      mod = 1.1
      expected = 21.5 # 21.494
      expected_price = BigDecimal.new("#{expected}", 2)
      @valid.price_mod mod
      assert_equal expected_price.to_s("F") , @valid.price.to_s("F")
    end
  end

  def test_mod_price_1_0001
    DB.transaction(rollback: :always) do
      mod = 1.009
      expected = 20 # 20.002
      expected_price = BigDecimal.new("#{expected}", 2)
      @valid.price_mod mod
      assert_equal expected_price.to_s("F") , @valid.price.to_s("F")
    end
  end

  def test_mod_price_1_1
    DB.transaction(rollback: :always) do
      mod = 1.1
      expected = 21.5 # 21.494
      expected_price = BigDecimal.new("#{expected}", 2)
      @valid.price_mod mod
      assert_equal expected_price.to_s("F") , @valid.price.to_s("F")
    end
  end

  def test_mod_price_1_01
    DB.transaction(rollback: :always) do
      mod = 1.01
      expected = 20 # 19.7354
      expected_price = BigDecimal.new("#{expected}", 2)
      @valid.price_mod mod
      assert_equal expected_price.to_s("F") , @valid.price.to_s("F")
    end
  end

  def test_mod_price_1_11
    DB.transaction(rollback: :always) do
      mod = 1.11
      expected = 22 # 21.6894
      expected_price = BigDecimal.new("#{expected}", 2)
      @valid.price_mod mod
      assert_equal expected_price.to_s("F") , @valid.price.to_s("F")
    end
  end

  def test_mod_price_1_13
    DB.transaction(rollback: :always) do
      mod = 1.13
      expected = 22.5 # 22.0802
      expected_price = BigDecimal.new("#{expected}", 2)
      @valid.price_mod mod
      assert_equal expected_price.to_s("F") , @valid.price.to_s("F")
    end
  end

  def test_mod_price_1_5
    DB.transaction(rollback: :always) do
      mod = 1.5
      expected = 29.5 # 29.31
      expected_price = BigDecimal.new("#{expected}", 2)
      @valid.price_mod mod
      assert_equal expected_price.to_s("F") , @valid.price.to_s("F")
    end
  end

  def test_mod_price_0_89
    DB.transaction(rollback: :always) do
      mod = 0.89
      expected = 17.5 # 17.3906
      expected_price = BigDecimal.new("#{expected}", 2)
      @valid.price_mod mod
      assert_equal expected_price.to_s("F") , @valid.price.to_s("F")
    end
  end

  def test_mod_price_0_01
    DB.transaction(rollback: :always) do
      mod = 0.01
      expected = 0.5 # 0.1954
      expected_price = BigDecimal.new("#{expected}", 2)
      @valid.price_mod mod
      assert_equal expected_price.to_s("F") , @valid.price.to_s("F")
    end
  end

  def test_mod_price_5_123
    DB.transaction(rollback: :always) do
      mod = 5.123
      expected = 101 # 100.10342
      expected_price = BigDecimal.new("#{expected}", 2)
      @valid.price_mod mod
      assert_equal expected_price.to_s("F") , @valid.price.to_s("F")
    end
  end

  def test_should_reject_nil_numerical_values
    DB.transaction(rollback: :always) do
      product = Product.new.get_rand
      product.ideal_stock = 10
      hash = {ideal_stock: nil}
      product.update_from_hash hash
      assert_equal 10, product.ideal_stock
    end
  end

  def test_should_ignore_non_present_values
    DB.transaction(rollback: :always) do
      product = Product.new.get_rand
      product.ideal_stock = 10
      hash = {}
      product.update_from_hash hash
      assert_equal 10, product.ideal_stock
    end
  end

  def test_should_reject_invalid_strings_in_numerical_values
    DB.transaction(rollback: :always) do
      product = Product.new.get_rand
      product.ideal_stock=10
      hash = {ideal_stock: "a"}
      product.update_from_hash hash
      assert_equal 10, product.ideal_stock
    end
  end

  def test_should_reject_badly_formatted_numbers
    DB.transaction(rollback: :always) do
      product = Product.new.get_rand
      product.ideal_stock=10
      hash = {ideal_stock: "1..1"}
      product.update_from_hash hash
      assert_equal 10, product.ideal_stock
    end
  end


  def test_should_update_from_hash
    DB.transaction(rollback: :always) do
      hash = {ideal_stock: "99,00", stock_warehouse_1: "100,00", buy_cost: "1,0", sale_cost: "1,0"}
      @valid.update_from_hash hash
      assert_equal 99, @valid.ideal_stock
      assert_equal 100, @valid.stock_warehouse_1
    end
  end

  def test_save_when_updated_from_hash
    DB.transaction(rollback: :always) do
      hash = {ideal_stock: "99,00", ideal_markup: "100,00", buy_cost: "1,0", sale_cost: "1,0"}
      product = Product.new.get_rand
      product.update_from_hash hash
      product.save validate: false, columns: Product::COLUMNS
      product = Product.new.get product.p_id
      assert_equal 99, product.ideal_stock
      assert_equal 100, product.ideal_markup
    end
  end


  def test_valid_products
    DB.transaction(rollback: :always) do
      products = Product.new.get_list
      invalid = []
      products.each do |product| 
        invalid << product unless product.valid?
        product.save validate: false, columns: Product::COLUMNS
      end
      invalid.each { |product| pp product.errors.full_messages }
    end
  end


end
