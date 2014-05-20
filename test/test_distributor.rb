require_relative 'prerequisites'

class DistributorTest < Test::Unit::TestCase

  def setup
    @valid_product = Product.new.get_rand
    @valid_product.sale_cost = BigDecimal.new 10
    @valid_product.price = BigDecimal.new 20
    assert_equal @valid_product.price, BigDecimal.new(20), "Shit"
    @valid_product.exact_price = BigDecimal.new 19.54, 5
    @valid_product.recalculate_markups
    @valid_product.p_name = "ProductTest @valid_product"
  end

  def test_should_get_distributors
    p_mila = Product[941]
    assert_equal 1, p_mila.distributors.count

    d_mila = Distributor[15]
    assert d_mila.products.count > 1
  end

  def test_should_add_product_to_distributor
    DB.transaction(rollback: :always, isolation: :uncommitted) do
      distributor = Distributor.new.get_rand
      old_count = distributor.products.count
      distributor.add_product @valid_product
      new_count = distributor.products.count
      assert_equal old_count+1 , new_count
    end
  end

  def test_should_add_multiple_distributors_to_product_and_get_them_orderred_by_date_added
    DB.transaction(rollback: :always, isolation: :uncommitted) do
      distributor1 = Distributor.new.get_rand
      distributor2 = Distributor.new.get_rand

      distributor1.add_product @valid_product
      distributor2.add_product @valid_product
      assert_equal  distributor2.d_id, @valid_product.distributors.last.d_id
    end
  end

end
