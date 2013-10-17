require_relative 'prerequisites'

class ProductMaterialTest < Test::Unit::TestCase

  def test_should_get_products_with_category
    @material = Material.new.get_by_id 2, Location::W1
    @products = @material.products
    assert_equal("Body Painting", @products.first.values[:c_name])
  end

  def good_query
    "select p.p_name, part_qty from products p join products_parts using(p_id) join products p2 on products_parts.part_id = p2.p_id;"

    "
    select part_id as p_id, part_qty, p_name from products_parts
    JOIN products ON part_id=p_id
    where product_id = 194
    ;







    select part_id, p_name, part_qty from products
    join products_parts ON part_id=products.p_id and products_parts.product_id=194
    ;

    SELECT part_id, p_name, part_qty from products
      INNER JOIN (SELECT * FROM `products_parts` WHERE ( product_id = 194)) AS `t1` ON (`t1`.`product_id` = `products`.`p_id`);

    "
    parts = DB[Sequel.as(:products, :p)].select(:p__p_id, :products_parts__part_id, :p__p_name, :part_qty)
                .join(:products_parts, products_parts__p_id: :p__p_id)
                .join(:products, products_parts__part_id: :products__p_id)
                # .where(p__p_id: 192)
end

  def mat
      mat1 = Material.select_group(:materials__m_id, :m_name, :c_id, :materials__created_at)
                  .left_join(:bulks, [:m_id])
                  .select_append{sum(:b_qty).as(m_qty)}
                  .select_append{max(:b_price).as(m_price)}
                  .select_append{:m_name}
                  .select_append{:materials__created_at}
                  .where(materials__m_id: id.to_i)
                  .first
  end

  # def test_should_get_product_with_relations

  #   p = Product[194].parts
  #   assert(p.count > 0)
  #   p.each do |part|
  #     assert_equal(part[:part_id].class, Integer)
  #     assert_equal(part[:part_qty].class, BigDecimal)
  #   end
  #   p p


  #   p = Product[194].materials

  #   p.each do |prod|
  #     p ""
  #     pp prod.class
  #   end
  #   p p
  # end

end
