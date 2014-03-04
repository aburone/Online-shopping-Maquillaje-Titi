require_relative 'prerequisites'

class ProductMaterialTest < Test::Unit::TestCase

  def test_should_get_products_with_category
    @material = Material.new.get_by_id 2, Location::W1
    @products = @material.products
    assert_equal("Body Painting", @products.first.values[:c_name])
  end
end
