require_relative 'prerequisites'

class SupplyTest < Test::Unit::TestCase

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


  def test_should_ideal_stock_should_not_be_modified_by_stored_procedure
    DB.transaction(rollback: :always, isolation: :uncommitted) do
      product = Product.new.get 135
      product.direct_ideal_stock = 5
      product.save
      product = Product.new.get 135
      assert_equal product.direct_ideal_stock, 5, "Erroneous ideal stock "
    end
  end


  def test_should_calculate_ideal_stock
    DB.transaction(rollback: :always, isolation: :uncommitted) do
      product = Product.new.get 135
      product.update_ideal_stock
      # ap product.p_name
      # p "ideal global "
      # ap product.inventory(1).global.ideal.to_s("F")

      # ap "assemblies"
      calculated_indirect_ideal_stock = BigDecimal.new(0)
      product.assemblies.each do |assembly|
        assembly.update_ideal_stock

        # ap assembly.p_name
        # ap "global ideal"
        # ap assembly.inventory(1).global.ideal.to_s("F")


        calculated_indirect_ideal_stock += assembly[:part_qty] * assembly.inventory(1).global.ideal / 2 unless assembly.archived #divido para considerar solo una locacion
      end
      calculated_indirect_ideal_stock *= 2
      assert_equal calculated_indirect_ideal_stock.round(2).to_s("F"), product.indirect_ideal_stock.round(2).to_s("F"), "Erroneous indirect ideal stock"
      assert_equal (calculated_indirect_ideal_stock + product.direct_ideal_stock * 2).round(2).to_s("F"), product.ideal_stock.round(2).to_s("F"), "Erroneous ideal stock"

      assert_equal BigDecimal.new(50.00, 6).round(2).to_s("F"), calculated_indirect_ideal_stock.round(2).to_s("F"), "Erroneous calculated_indirect_ideal_stock"
      # assert_equal BigDecimal.new(170.00, 6).round(2).to_s("F"), product.ideal_stock.round(2).to_s("F"), "Erroneous ideal stock"
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

  def test_get_items_in_assemblies
    DB.transaction(rollback: :always, isolation: :uncommitted) do
      product = Product.new.get 193
      items = Item.new.get_by_product(product.p_id).all
      # ap items
    end
  end

  def test_set_assembly_id
    # parts = PartsToAssemblies.get_parts_via_part_id 137
    # product = Product.new.get 137
    # ap product.inventory(1)
  end




######################################################################33

  def test_get_supply_from_product
    product = Product.new.get 135
    supply = product.supply
    assert_equal product.p_id, supply.p_id
  end

  def test_get_product_from_supply
    supply = Supply[135]
    if supply.nil?
      ap "No supply record for 135"
    else
      product = supply.product
      assert_equal supply.p_id, product.p_id
    end
  end

  def test_new_supply_should_be_empty
    supply = Supply.new
    assert supply.empty?
  end

  def test_init_new_supply_should_fill_defaults
    DB.transaction(rollback: :always, isolation: :uncommitted) do
      supply = Supply.new.init
      Supply.db_schema.map { |column| assert supply[column[0].to_sym].to_f >= 0 unless column[0].to_sym == :p_id }
    end
  end

  def test_get_nil_supply_should_return_default
    supply = Supply.new.get nil
    Supply.db_schema.map { |column| assert supply.respond_to? column[0].to_sym }
  end


  def test_should_not_save_empty_supply
    assert_raise Sequel::NotNullConstraintViolation do
      Supply.new.init.save
    end
  end

  def test_init_supply_should_fill_missing_values
    DB.transaction(rollback: :always, isolation: :uncommitted) do
      Product.new.save validate: false
      product = Product.last
      supply = Supply.new.get product.p_id
      assert_equal product.p_id, supply.p_id
    end
  end

  def test_getting_a_product_supply_should_get_old_values
    DB.transaction(rollback: :always, isolation: :uncommitted) do
      product = Product.new.get 135
      supply = product.supply
      Supply::PRODUCT_EQ.map do |src_key, dst_key|
        # assert_equal product[src_key.to_sym], supply[dst_key.to_sym], "#{src_key}: #{product[src_key.to_sym].to_s('F')} <> #{supply[dst_key.to_sym].to_s('F')}"
      end
      assert !product.empty?
      Supply::INVENTORY_EQ.each do |location|
        Supply::INVENTORY_EQ[location[0]].map do |src_key, dst_key|
          # assert eval("product.inventory(1).#{location[0]}.#{src_key} == supply.#{dst_key}"), "#{src_key} (#{ eval("product.inventory(1).#{location[0]}.#{src_key}")}) != #{dst_key} (#{ eval("supply.#{dst_key}")})"
        end
      end
    end
  end

  def test_supply_entries_should_equal_products_entries
    assert_equal Product.count, Supply.count
  end


  def test_supply_should_be_filled
    DB.transaction(rollback: :always, isolation: :uncommitted) do
      base = Product.new.get 135

      #whole
      assert_equal base.supply.s1_whole + base.supply.s1_whole_en_route, base.supply.s1_whole_future
      assert_equal base.supply.s2_whole + base.supply.s2_whole_en_route, base.supply.s2_whole_future
      assert_equal base.supply.stores_whole + base.supply.stores_whole_en_route, base.supply.stores_whole_future

      assert_equal base.supply.s1_whole + base.supply.s2_whole, base.supply.stores_whole
      assert_equal base.supply.s1_whole_en_route + base.supply.s2_whole_en_route, base.supply.stores_whole_en_route
      assert_equal base.supply.s1_whole_future + base.supply.s2_whole_future, base.supply.stores_whole_future


      assert_equal base.supply.w1_whole + base.supply.w1_whole_en_route, base.supply.w1_whole_future
      assert_equal base.supply.w2_whole + base.supply.w2_whole_en_route, base.supply.w2_whole_future
      assert_equal base.supply.warehouses_whole + base.supply.warehouses_whole_en_route, base.supply.warehouses_whole_future

      assert_equal base.supply.w1_whole + base.supply.w2_whole, base.supply.warehouses_whole
      assert_equal base.supply.w1_whole_en_route + base.supply.w2_whole_en_route, base.supply.warehouses_whole_en_route
      assert_equal base.supply.w1_whole_future + base.supply.w2_whole_future, base.supply.warehouses_whole_future


      #part stores
      assert_equal base.supply.s1_part + base.supply.s1_part_en_route, base.supply.s1_part_future
      assert_equal base.supply.s2_part + base.supply.s2_part_en_route, base.supply.s2_part_future
      assert_equal base.supply.s1_part + base.supply.s2_part, base.supply.stores_part
      assert_equal base.supply.s1_part_en_route + base.supply.s2_part_en_route, base.supply.stores_part_en_route
      assert_equal base.supply.stores_part + base.supply.stores_part_en_route, base.supply.stores_part_future

      #part warehouses
      assert_equal base.supply.w1_part + base.supply.w1_part_en_route, base.supply.w1_part_future

      assert_equal base.supply.w2_part + base.supply.w2_part_en_route, base.supply.w2_part_future
      assert_equal base.supply.w1_part + base.supply.w2_part, base.supply.warehouses_part
      assert_equal base.supply.w1_part_en_route + base.supply.w2_part_en_route, base.supply.warehouses_part_en_route
      assert_equal base.supply.warehouses_part + base.supply.warehouses_part_en_route, base.supply.warehouses_part_future


      #totals
      assert_equal base.supply.s1_whole + base.supply.s1_part, base.supply.s1
      assert_equal base.supply.s2_whole + base.supply.s2_part, base.supply.s2


      # ap PartsToAssemblies.get_parts_via_part_id_en_route_to_location(base.p_id, Location::S1).all.count


      assert_equal base.supply.w1_part + base.supply.w1_part_en_route, base.supply.w1_part_future
      assert_equal base.supply.w2_part + base.supply.w2_part_en_route, base.supply.w2_part_future
      assert_equal base.supply.warehouses_part + base.supply.warehouses_part_en_route, base.supply.warehouses_part_future

      assert_equal base.supply.w1_part + base.supply.w2_part, base.supply.warehouses_part
      assert_equal base.supply.w1_part_en_route + base.supply.w2_part_en_route, base.supply.warehouses_part_en_route
      assert_equal base.supply.w1_part_future + base.supply.w2_part_future, base.supply.warehouses_part_future
    end
  end

  def test_ideal_stock
    DB.transaction(rollback: :always, isolation: :uncommitted) do
      base = Product.new.get 135
      base.direct_ideal_stock = 10
      # p ""
      # p base.p_name
      assemblies = base.assemblies
      assemblies.each do |assy|
        assy.direct_ideal_stock = 5
        assy.save
        assy = Product.new.get assy.p_id
      end
      base.save


      assemblies = base.assemblies
      assemblies.each do |assy|
        # ap "#{assy.p_name} (#{assy.supply.stores_whole})"
        # assert_equal assy.supply.stores_whole, assy.direct_ideal_stock
        assert_equal assy.supply.global_ideal, assy.ideal_stock, "#{assy.supply.global_ideal.to_s('F')} != #{assy.ideal_stock.to_s('F')}"
        parts = assy.parts
        # parts.each { |part| ap "  #{part[:part_qty].to_s("F")} x #{part.p_name}" if part.p_id == base.p_id}
      end

      base.supply.keys.each do |key|
        # ap "#{key}: #{base.supply[key].to_s('F')}" if key.to_s.include? "s1"
      end
    end
  end


end
