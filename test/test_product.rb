require_relative 'prerequisites'

class ProductTest < Test::Unit::TestCase

  def setup
    @valid = Product.new.get_rand
    @valid.sale_cost = BigDecimal.new 10
    @valid.price = BigDecimal.new 20
    assert_equal @valid.price, BigDecimal.new(20), "Shit"
    @valid.exact_price = BigDecimal.new 19.54, 5
    @valid.recalculate_markups
    @valid.p_name = "ProductTest @valid"
  end

  def test_get_rand
    p = Product.new.get_rand
    assert_equal(Product, p.class)
  end

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

  def test_should_add_label_to_product
    DB.transaction(rollback: :always, isolation: :uncommitted) do
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
    DB.transaction(rollback: :always, isolation: :uncommitted) do
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

  def test_check_cost
    Product.all.each do |product|
      if product.exact_price < product.sale_cost
        p "Inconsistent product (price lower than cost) #{product.p_id}: #{product.exact_price.to_s "F"} < #{product.sale_cost.to_s "F"}"
        product.exact_price = product.sale_cost * 2
        product.save
      end
      if product.price*1.1 < product.exact_price
        p "Inconsistent product (price lower than exact_price) #{product.p_id}: #{(product.price*1.1).to_s "F"} < #{product.exact_price.to_s "F"}"
        product.price = product.price = product.exact_price
        product.save
      end
    end
  end

  def test_mod_price_should_ignore_zero
    expected_price = @valid.price
    @valid.price_mod 0
    assert_equal expected_price, @valid.price
  end

  def test_mod_price_should_ignore_one
    expected_price = @valid.exact_price.round(1)
    @valid.price_mod 1
    assert_equal expected_price.to_s("F"), @valid.price.to_s("F")
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
    DB.transaction(rollback: :always, isolation: :uncommitted) do
      mod = 1.1
      expected = 21.5 # 21.494
      expected_price = BigDecimal.new("#{expected}", 2)
      @valid.price_mod mod
      assert_equal expected_price.to_s("F") , @valid.price.to_s("F")
    end
  end

  def test_mod_price_0_89
    DB.transaction(rollback: :always, isolation: :uncommitted) do
      mod = 0.89
      expected = 17.4 # 19.54 * 0.89 = 17.39
      expected_price = BigDecimal.new("#{expected}", 2)
      @valid.price_mod mod
      assert_equal expected_price.to_s("F") , @valid.price.to_s("F")
    end
  end

  def test_mod_price_0_01
    DB.transaction(rollback: :always, isolation: :uncommitted) do
      mod = 0.01
      expected = 0.2 # 0.2
      expected_price = BigDecimal.new("#{expected}", 2)
      @valid.price_mod mod
      assert_equal expected_price.to_s("F") , @valid.price.to_s("F")
    end
  end

  def test_mod_price_1_0009
    DB.transaction(rollback: :always, isolation: :uncommitted) do
      mod = 1.0009
      expected = 19.6 # 19.54 * 1.009 = 19.5575
      expected_price = BigDecimal.new("#{expected}", 2)
      @valid.price_mod mod
      assert_equal expected_price.to_s("F") , @valid.price.to_s("F")
    end
  end

  def test_mod_price_1_1
    DB.transaction(rollback: :always, isolation: :uncommitted) do
      mod = 1.1
      expected = 21.5 # 21.494
      expected_price = BigDecimal.new("#{expected}", 2)
      @valid.price_mod mod
      assert_equal expected_price.to_s("F") , @valid.price.to_s("F")
    end
  end

  def test_mod_price_1_01
    DB.transaction(rollback: :always, isolation: :uncommitted) do
      mod = 1.01
      expected = 19.7 # 19.7354
      expected_price = BigDecimal.new("#{expected}", 2)
      @valid.price_mod mod
      assert_equal expected_price.to_s("F") , @valid.price.to_s("F")
    end
  end

  def test_mod_price_1_11
    DB.transaction(rollback: :always, isolation: :uncommitted) do
      mod = 1.11
      expected = 21.7 # 19.54 * 1.11 = 21.68
      expected_price = BigDecimal.new("#{expected}", 2)
      @valid.price_mod mod
      assert_equal expected_price.to_s("F") , @valid.price.to_s("F")
    end
  end

  def test_mod_price_1_13
    DB.transaction(rollback: :always, isolation: :uncommitted) do
      mod = 1.13
      expected = 22.1 # 19.54 * 1.13 = 22.08
      expected_price = BigDecimal.new("#{expected}", 2)
      @valid.price_mod mod
      assert_equal expected_price.to_s("F") , @valid.price.to_s("F")
    end
  end

  def test_mod_price_1_5
    DB.transaction(rollback: :always, isolation: :uncommitted) do
      mod = 1.5
      expected = 29.3 # 19.54 * 1.5 = 29.31
      expected_price = BigDecimal.new("#{expected}", 2)
      @valid.price_mod mod
      assert_equal expected_price.to_s("F") , @valid.price.to_s("F")
    end
  end

  def test_mod_price_5_123
    DB.transaction(rollback: :always, isolation: :uncommitted) do
      mod = 5.123
      expected = 100 # 19.54 * 5.123 = 100.10342
      expected_price = BigDecimal.new("#{expected}", 2)
      @valid.price_mod mod
      assert_equal expected_price.to_s("F") , @valid.price.to_s("F")
    end
  end

  def test_mod_price_with_comma_1_0009
    DB.transaction(rollback: :always, isolation: :uncommitted) do
      mod = "1,0009"
      expected = 19.6 # 19.54 * 1.009 = 19.5575
      expected_price = BigDecimal.new("#{expected}", 2)
      @valid.price_mod mod
      assert_equal expected_price.to_s("F") , @valid.price.to_s("F")
    end
  end

  def test_mod_price_with_comma_1_1
    DB.transaction(rollback: :always, isolation: :uncommitted) do
      mod = "1,1"
      expected = 21.5 # 21.494
      expected_price = BigDecimal.new("#{expected}", 2)
      @valid.price_mod mod
      assert_equal expected_price.to_s("F") , @valid.price.to_s("F")
    end
  end

  def test_mod_price_with_comma_1_01
    DB.transaction(rollback: :always, isolation: :uncommitted) do
      mod = "1,01"
      expected = 19.7 # 19.7354
      expected_price = BigDecimal.new("#{expected}", 2)
      @valid.price_mod mod
      assert_equal expected_price.to_s("F") , @valid.price.to_s("F")
    end
  end

  def test_mod_price_with_comma_1_11
    DB.transaction(rollback: :always, isolation: :uncommitted) do
      mod = "1,11"
      expected = 21.7 # 19.54 * 1.11 = 21.68
      expected_price = BigDecimal.new("#{expected}", 2)
      @valid.price_mod mod
      assert_equal expected_price.to_s("F") , @valid.price.to_s("F")
    end
  end

  def test_mod_price_with_comma_1_13
    DB.transaction(rollback: :always, isolation: :uncommitted) do
      mod = "1,13"
      expected = 22.1 # 19.54 * 1.13 = 22.08
      expected_price = BigDecimal.new("#{expected}", 1)
      @valid.price_mod mod
      assert_equal expected_price.to_s("F") , @valid.price.to_s("F")
    end
  end

  def test_mod_price_with_comma_1_5
    DB.transaction(rollback: :always, isolation: :uncommitted) do
      mod = "1,5"
      expected = 29.3 # 19.54 * 1.5 = 29.31
      expected_price = BigDecimal.new("#{expected}", 2)
      @valid.price_mod mod
      assert_equal expected_price.to_s("F") , @valid.price.to_s("F")
    end
  end

  def test_mod_price_with_comma_0_89
    DB.transaction(rollback: :always, isolation: :uncommitted) do
      mod = "0.89"
      expected = 17.4 # 19.54 * 0.89 = 17.39
      expected_price = BigDecimal.new("#{expected}", 2)
      @valid.price_mod mod
      assert_equal expected_price.to_s("F") , @valid.price.to_s("F")
    end
  end

  def test_mod_price_with_comma_0_01
    DB.transaction(rollback: :always, isolation: :uncommitted) do
      mod = "0,01"
      expected = 0.2 # 0.2
      expected_price = BigDecimal.new("#{expected}", 2)
      @valid.price_mod mod
      assert_equal expected_price.to_s("F") , @valid.price.to_s("F")
    end
  end

  def test_mod_price_with_comma_5_123
    DB.transaction(rollback: :always, isolation: :uncommitted) do
      mod = "5,123"
      expected = 100 # 19.54 * 5.123 = 100.10342
      expected_price = BigDecimal.new("#{expected}", 2)
      @valid.price_mod mod
      assert_equal expected_price.to_s("F") , @valid.price.to_s("F")
    end
  end

  def test_should_reject_nil_numerical_values
    DB.transaction(rollback: :always, isolation: :uncommitted) do
      product = Product.new.get_rand
      product.direct_ideal_stock=10
      product.indirect_ideal_stock=0
      hash = {direct_ideal_stock: nil}
      product.update_from_hash hash
      assert_equal 10, product.ideal_stock
    end
  end

  def test_should_ignore_non_present_values
    DB.transaction(rollback: :always, isolation: :uncommitted) do
      product = Product.new.get_rand
      product.direct_ideal_stock=10
      product.indirect_ideal_stock=0
      hash = {}
      product.update_from_hash hash
      assert_equal BigDecimal.new(10).to_s("F"), product.ideal_stock.to_s("F"), "non_present_values"
    end
  end

  def test_should_reject_invalid_strings_in_numerical_values
    DB.transaction(rollback: :always, isolation: :uncommitted) do
      product = Product.new.get_rand
      product.direct_ideal_stock=10
      product.indirect_ideal_stock=10
      hash = {direct_ideal_stock: "a"}
      product.update_from_hash hash
      assert_equal 20, product.ideal_stock
    end
  end

  def test_should_reject_badly_formatted_numbers
    DB.transaction(rollback: :always, isolation: :uncommitted) do
      product = Product.new.get_rand
      product.direct_ideal_stock=10
      product.indirect_ideal_stock=10
      hash = {direct_ideal_stock: "1..1"}
      product.update_from_hash hash
      assert_equal 20, product.ideal_stock, "formatted_numbers"
    end
  end


  def test_should_update_from_hash
    DB.transaction(rollback: :always, isolation: :uncommitted) do
      hash = {direct_ideal_stock: "90,00", indirect_ideal_stock: "90,00", stock_warehouse_1: "100,00", buy_cost: "1,0", sale_cost: "1,0"}
      @valid.update_from_hash hash
      assert_equal BigDecimal.new(180).to_s("F"), @valid.ideal_stock.to_s("F"), "Erroneous ideal_stock 1"
      assert_equal 100, @valid.stock_warehouse_1
    end
  end

  def test_save_when_updated_from_hash
    DB.transaction(rollback: :always, isolation: :uncommitted) do
      hash = {direct_ideal_stock: "5", indirect_ideal_stock: "7", ideal_markup: "100,00", buy_cost: "1,0", sale_cost: "1,0"}
      product = Product.new.get_rand
      product.update_from_hash hash
      product.save
      product = Product.new.get product.p_id
      assert_equal BigDecimal.new(12), product.ideal_stock, "Erroneous ideal_stock 2"
      assert_equal 100, product.ideal_markup, "Erroneous ideal_markup"
    end
  end

  def test_should_duplicate_products
    DB.transaction(rollback: :always, isolation: :uncommitted) do
      orig = Product[193]
      dest = orig.duplicate
      copied_columns = Product::ATTRIBUTES - Product::EXCLUDED_ATTRIBUTES_IN_DUPLICATION
      copied_columns.each do |col|
        assert_equal orig[col], dest[col]
      end
      dest_id =  dest[:p_id]
      orig = Product[193].parts
      dest = Product[dest_id].parts
      assert_equal orig.size, dest.size
      for i in 0...orig.size
        assert_equal orig[i][:p_id], dest[i][:p_id]
        assert_equal orig[i][:part_qty], dest[i][:part_qty]
      end
      orig = Product[193].materials
      dest = Product[dest_id].materials
      assert_equal orig.size, dest.size
      for i in 0...orig.size
        assert_equal orig[i][:m_id], dest[i][:m_id]
        assert_equal orig[i][:m_qty], dest[i][:m_qty]
      end
    end
  end

  def test_should_add_material_to_product
    DB.transaction(rollback: :always, isolation: :uncommitted) do
      material = Material.new.get_rand
      material[:m_qty] = 5
      prev_count = @valid.materials.count
      @valid.add_material material
      new_count = @valid.materials.count
      assert_equal prev_count + 1, new_count
    end
  end

  def test_should_not_allow_to_add_material_with_zero_qty_to_product
    DB.transaction(rollback: :always, isolation: :uncommitted) do
      material = Material.new.get_rand
      material[:m_qty] = 0
      prev_count = @valid.materials.count
      @valid.add_material material
      new_count = @valid.materials.count
      assert_equal prev_count , new_count
      assert_equal 1, @valid.errors.count
    end
  end

  def test_should_update_material_qty
    DB.transaction(rollback: :always, isolation: :uncommitted) do
      material = Material.new.get_rand
      material[:m_qty] = 5
      count1 = @valid.materials.count
      new_material = @valid.add_material material
      count2 = @valid.materials.count
      assert_equal count1 + 1, count2, "Error adding"
      assert_equal BigDecimal.new(5), new_material[:m_qty], "Error adding"

      material[:m_qty] = -5
      updated_material = @valid.update_material material
      count3 = @valid.materials.count
      assert_equal count2 , count3, "Error updating negative"
      assert_equal 1, @valid.errors.count, "Error updating negative"
      assert_equal BigDecimal.new(5), updated_material[:m_qty], "Error updating negative"

      material[:m_qty] = 3
      updated_material = @valid.update_material material
      count4 = @valid.materials.count
      assert_equal count3, count4, "Error updating"
      assert_equal 1, @valid.errors.count, "Error updating"
      assert_equal BigDecimal.new(3), updated_material[:m_qty], "Error updating"

      material[:m_qty] = 0
      updated_material = @valid.update_material material
      count5 = @valid.materials.count
      assert_equal count4 - 1, count5, "Error removing"
      assert_equal 1, @valid.errors.count, "Error removing"
    end
  end

  def test_should_add_part_to_product
    DB.transaction(rollback: :always, isolation: :uncommitted) do
      part = Product.new.get_rand
      part[:part_qty] = 5
      prev_count = @valid.parts.count
      @valid.add_part part
      new_count = @valid.parts.count
      assert_equal prev_count + 1, new_count
    end
  end

  def test_should_not_allow_to_add_part_with_zero_qty_to_product
    DB.transaction(rollback: :always, isolation: :uncommitted) do
      part = Product.new.get_rand
      part[:part_qty] = 0
      prev_count = @valid.parts.count
      @valid.add_part part
      new_count = @valid.parts.count
      assert_equal prev_count , new_count
      assert_equal 1, @valid.errors.count
    end
  end

  def test_should_update_part_qty
    DB.transaction(rollback: :always, isolation: :uncommitted) do
      part = Product.new.get_rand
      part[:part_qty] = 5
      count1 = @valid.parts.count
      new_part = @valid.add_part part
      count2 = @valid.parts.count
      assert_equal count1 + 1, count2, "Error adding"
      assert_equal BigDecimal.new(5), new_part[:part_qty], "Error adding"

      part[:part_qty] = -5
      updated_part = @valid.update_part part
      count3 = @valid.parts.count
      assert_equal count2 , count3, "Error updating negative"
      assert_equal 1, @valid.errors.count, "Error updating negative"
      assert_equal BigDecimal.new(5), updated_part[:part_qty], "Error updating negative"

      part[:part_qty] = 3
      updated_part = @valid.update_part part
      count4 = @valid.parts.count
      assert_equal count3, count4, "Error updating"
      assert_equal 1, @valid.errors.count, "Error updating"
      assert_equal BigDecimal.new(3), updated_part[:part_qty], "Error updating"

      part[:part_qty] = 0
      updated_part = @valid.update_part part
      count5 = @valid.parts.count
      assert_equal count4 - 1, count5, "Error removing"
      assert_equal 1, @valid.errors.count, "Error removing"
    end
  end

  def test_should_get_product_by_sku
    DB.transaction(rollback: :always, isolation: :uncommitted) do
      sku = rand
      @valid.sku = sku
      orig = @valid.save
      product = Product.new.get_by_sku sku
      assert_equal orig.p_id, product.p_id
    end
  end

  def test_should_get_an_empty_product_for_invalid_sku
    DB.transaction(rollback: :always, isolation: :uncommitted) do
      sku = rand
      product = Product.new.get_by_sku sku
      assert product.empty?
    end
  end

  def test_should_clean_given_sku
    DB.transaction(rollback: :always, isolation: :uncommitted) do
      sku = "    a e i \n \r \t o     u    "
      @valid.sku = sku
      assert_equal "a e i o u", @valid.sku
    end
  end

  def test_should_return_nil_if_empty_sku
    DB.transaction(rollback: :always, isolation: :uncommitted) do
      sku = ""
      @valid.sku = sku
      assert_equal nil, @valid.sku
    end
  end

  def test_should_get_materials_cost
    product = Product[2]
    expected_cost =  BigDecimal.new(0, 3)
    product.materials.map do |material|
      expected_cost +=  material[:m_qty] * material[:m_price]
      # ap "#{material[:m_qty].to_s("F")} * #{material[:m_price].to_s("F")}"
    end
    # 1 * 3.355 + 1 * 0.88 + 100 * 0.304 = 34.635
    assert_equal expected_cost.round(3).to_s("F"), product.materials_cost.to_s("F")
  end

  def test_should_ideal_stock_should_not_be_modified_by_stored_procedure
    DB.transaction(rollback: :always, isolation: :uncommitted) do
      product = Product.new.get 135
      product.ideal_stock = 10
      assert_equal 10, product.ideal_stock, "Erroneous ideal stock "
      product.save
      product = Product.new.get 135
      assert_equal 10, product.ideal_stock, "Erroneous ideal stock "
    end
  end

  def test_should_round_price_to_1_decimal_if_under_100
    DB.transaction(rollback: :always, isolation: :uncommitted) do
      @valid.price = 6.5555
      assert_equal BigDecimal.new(6.5, 1), @valid.price, "Erroneous price"
    end
  end

  def test_should_calculate_ideal_stock
    DB.transaction(rollback: :always, isolation: :uncommitted) do
      product = Product.new.get 135
      product.update_ideal_stock

      calculated_indirect_ideal_stock = BigDecimal.new(0)
      product.assemblies.each do |assembly|
        assembly.update_ideal_stock
        calculated_indirect_ideal_stock += assembly[:part_qty] * assembly.inventory(1).global.ideal unless assembly.archived
      end
      calculated_indirect_ideal_stock *= 2
      assert_equal calculated_indirect_ideal_stock.round(2).to_s("F"), product.indirect_ideal_stock.round(2).to_s("F"), "Erroneous indirect ideal stock"
      assert_equal (calculated_indirect_ideal_stock + product.direct_ideal_stock * 2).round(2).to_s("F"), product.ideal_stock.round(2).to_s("F"), "Erroneous ideal stock"

      assert_equal BigDecimal.new(101.32, 6).round(2).to_s("F"), calculated_indirect_ideal_stock.round(2).to_s("F"), "Erroneous calculated_indirect_ideal_stock"
      assert_equal BigDecimal.new(197.32, 6).round(2).to_s("F"), product.ideal_stock.round(2).to_s("F"), "Erroneous ideal stock"
      assert_equal 0, (product.ideal_stock - calculated_indirect_ideal_stock - product.direct_ideal_stock * 2).round, "Erroneous ideal stock relation"

    end
  end

  def test_inventory_should_return_same_values_as_stored_object
    product = Product.new.get 135
    assert_equal product.ideal_stock.round(2).to_s("F"), product.inventory(1).global.ideal.round(2).to_s("F"), "Stored and calculated are different"
  end

  def ideal_para_kits
    # ideal kits:  sumatoria( ideal_global_assembly )
    # ideal global: ( ideal_store_1 * 2 ) + ideal kits * 2
    # 48*2 + 59*2 = 96+118 = 214

    # necesidad: ideal_global - stock_global - assembly.global_stok
    # nececidad: desvio + sumatoria ( desvio.assembly )

    # 138 de pastilla blanca
  end

end

