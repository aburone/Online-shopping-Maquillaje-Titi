require_relative 'prerequisites'

class OrderTest < Test::Unit::TestCase

  def test_should_allow_only_one_packaging_order_open_per_user
    DB.transaction(rollback: :always) do
      assert_equal Order.new.create_packaging.o_id, Order.new.create_packaging.o_id
    end
  end

  def test_should_add_item_to_order
    DB.transaction(rollback: :always) do
      label = get_printed_label
      order = Order.new.create_packaging
      Product.new.get_rand.add_item label, order.o_id
      item = Item[label.i_id]
      assert_equal( item.class, Item)

      assert_equal( order.class, Order)
      items_before = order.items.count
      order.add_item(item)
      items_after = order.items.count
      assert_equal( items_before+1, items_after)
    end
  end

  def test_should_reject_to_add_items_with_status_new
    DB.transaction(rollback: :always) do
      order = Order.new.create_packaging
      item = get_new_item
      assert_equal R18n::t.errors.label_wasnt_printed, order.add_item(item)
    end
  end

  def test_should_remove_item_from_order
    DB.transaction(rollback: :always) do
      label = get_printed_label
      order = Order.new.create_packaging
      Product.new.get_rand.add_item(label, order.o_id)
      item = Item[label.i_id]

      order.add_item(item)
      items_before = order.items.count
      order.remove_item(item)
      items_after = order.items.count
      assert_equal( items_before-1, items_after)
    end
  end


  def test_should_remove_all_items_from_order
    DB.transaction(rollback: :always) do
      order = Order.new.create_packaging
      add_new_item order
      add_new_item order
      add_new_item order
      add_new_item order
      items_before = order.items.count
      order.remove_all_items
      items_after = order.items.count
      assert_equal( items_after, items_before-4)
    end
  end

  def test_should_get_materials
    DB.transaction(rollback: :always) do
      order = Order.new.create_packaging
      add_new_item order
      add_new_item order
      add_new_item order
      add_new_item order
      mat = order.materials
      mat.each do |m|
        assert( m.class == Material)
      end
    end
  end

  def test_shoud_get_parts
    DB.transaction(rollback: :always) do
      order = Order.new.create_packaging
      add_new_item_with_parts order
      add_new_item_with_parts order
      parts = order.parts
      assert_equal 10, parts.count
    end
  end

  def test_should_get_types
    assert Order::TYPES.class == Array
  end

  def test_should_alter_inventory
  end

  def add_new_item order
      label = get_printed_label
      Product.new.get_rand.add_item label, order.o_id
      item = Item[label.i_id]
      order.add_item(item)
  end

  def add_new_item_with_parts order
    label = get_printed_label
    Product[193].add_item label, order.o_id
    item = Item[label.i_id]
    order.add_item(item)
  end

  def test_remove_dash
    code = "BEE-B72"
    ret = Order.new.remove_dash_from_code(code)
    assert_equal("BEEB72", ret, "Invalid code returned #{ret}")
  end

  def test_should_get_order_by_code
    code = "BEE-B72"
    order = Order.new.get_order_by_code code
    assert_equal(2657, order.o_id)
  end

  def test_should_get_empty_order_with_error_if_the_code_is_invalid
    code = "XXX-XXXX"
    order = Order.new.get_order_by_code code
    assert( order.empty? == true , "The order isn't empty or is not an order (nil?)")
    assert_equal [t.errors.inexistent_order.to_s, t.errors.invalid_order.to_s].flatten.join(": "), order.errors.to_a.flatten.join(": ")
  end

end
