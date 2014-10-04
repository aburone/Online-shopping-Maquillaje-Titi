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


  # def test_should_ideal_stock_should_not_be_modified_by_stored_procedure
  #   DB.transaction(rollback: :always, isolation: :uncommitted) do
  #     product = Product.new.get 135
  #     product.direct_ideal_stock = 5
  #     assert_equal product.indirect_ideal_stock + 5, product.ideal_stock, "Erroneous ideal stock "
  #     product.save
  #     product = Product.new.get 135
  #     assert_equal product.indirect_ideal_stock + 5, product.ideal_stock, "Erroneous ideal stock "
  #   end
  # end


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

  # def test_get_items_in_assemblies
  #   DB.transaction(rollback: :always, isolation: :uncommitted) do
  #     product = Product.new.get 193
  #     items = Item.new.get_by_product(product.p_id).all
  #     # ap items
  #   end
  # end

  def test_set_assembly_id
    # parts = PartsToAssemblies.new.get_parts_with_part_p_id 137
    # product = Product.new.get 137
    # ap product.inventory(1)
  end




#-######################################################################33

  def test_get_supply
    # product = Product[135]
    # assert product.supply.respond_to? :p_id
  end

  def test_init_supply
    DB.transaction(rollback: :always, isolation: :uncommitted) do
      # product = Product[135]
      # ap product
      # ap product.supply
    end
  end

  def test_init_nil_supply
    DB.transaction(rollback: :always, isolation: :uncommitted) do
      product = Product.new
      # ap product
      # ap product.supply
    end
  end


end
