require_relative 'prerequisites'

class OrderTest < Test::Unit::TestCase

  def test_should_allow_only_one_packaging_order_open_per_user
    DB.transaction(rollback: :always, isolation: :uncommitted) do
      assert_equal Order.new.create_or_load(Order::PACKAGING).o_id, Order.new.create_or_load(Order::PACKAGING).o_id
    end
  end

  def test_should_add_item_to_order
    DB.transaction(rollback: :always, isolation: :uncommitted) do
      label = get_printed_label
      order = Order.new.create_or_load(Order::PACKAGING)
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
    DB.transaction(rollback: :always, isolation: :uncommitted) do
      order = Order.new.create_or_load(Order::PACKAGING)
      item = get_new_item
      assert_equal R18n::t.errors.label_wasnt_printed, order.add_item(item)
    end
  end

  def test_should_remove_item_from_order
    DB.transaction(rollback: :always, isolation: :uncommitted) do
      label = get_printed_label
      order = Order.new.create_or_load(Order::PACKAGING)
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
    DB.transaction(rollback: :always, isolation: :uncommitted) do
      order = Order.new.create_or_load(Order::PACKAGING)
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
    DB.transaction(rollback: :always, isolation: :uncommitted) do
      order = Order.new.create_or_load(Order::PACKAGING)
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
    DB.transaction(rollback: :always, isolation: :uncommitted) do
      order = Order.new.create_or_load(Order::PACKAGING)
      add_new_item_with_parts order
      add_new_item_with_parts order
      parts = order.parts
      assert_equal 10, parts.count
    end
  end

  def add_new_item_with_parts order
    label = get_printed_label
    Product[193].add_item label, order.o_id
    item = Item[label.i_id]
    order.add_item(item)
  end

  def add_new_item order
    label = get_printed_label
    Product.new.get_rand.add_item label, order.o_id
    item = Item[label.i_id]
    order.add_item(item)
  end


  def test_remove_dash
    code = "BEE-B72"
    ret = Order.new.remove_dash_from_code(code)
    assert_equal("BEEB72", ret, "Invalid code returned #{ret}")
  end

  def test_should_not_allow_to_add_empty_items
    DB.transaction(rollback: :always, isolation: :uncommitted) do
      order = Order.new
      item = Item.new
      order.add_item item
      assert_equal order.errors.count, 1
      assert_equal "General: #{R18n::t.errors.cant_add_empty_items_to_order.to_s}", order.errors.to_a.flatten.join(": ")
    end
  end

  def test_return_orders_raise_error_if_called_with_incorrect_sale_id_and_there_is_another_return_order_in_progress
    DB.transaction(rollback: :always, isolation: :uncommitted) do
      User.new.current_location = Location::S1
      User.new.current_user_id = 1
      exception = assert_raise(ArgumentError) {Order.new.create_or_load_return 666}
      assert_equal("#{t.errors.sale_id_missmatch}", exception.message)
    end
  end

  def test_return_orders_should_reject_items_from_non_associated_sale
    DB.transaction(rollback: :always, isolation: :uncommitted) do
      User.new.current_location = Location::S1
      return_id = 6943
      sale_id = SalesToReturn.filter(return: return_id).first[:sale]
      bad_item = Item.new.get_for_return "338-11a22f99", return_id
      assert_equal 1, bad_item.errors.count
      assert_equal "Error de ingreso: Este item pertenece a la orden #{bad_item.sale_id}, mientras que la orden de venta actual es la #{sale_id}.", bad_item.errors.to_a.flatten.join(": ")
    end
  end

  def test_return_orders_should_accept_items_from_associated_sale
    DB.transaction(rollback: :always, isolation: :uncommitted) do
      User.new.current_location = Location::S1

      return_id = 6943
      good_item = Item.new.get_for_return "350-0e0bf7e3", return_id
      assert_equal good_item.errors.count, 0
    end
  end

  def test_return_orders_should_allow_items_from_sales_only
    DB.transaction(rollback: :always, isolation: :uncommitted) do
      User.new.current_location = Location::S1
      unsold_item = Item.new.get_for_return " 343-3dd0313b ", 6943
      assert_equal "#{t.return.errors.invalid_status.to_s}: #{t.return.errors.this_item_is_not_in_sold_status.to_s}", unsold_item.errors.to_a.flatten.join(": ")
    end
  end

  def test_should_get_a_zero_if_there_are_no_payments
    order = Order.new
    assert_equal 0, order.payments_total
  end

  def test_should_get_order_by_code
    code = "BEE-B72"
    order = Order.new.get_orders_at_location_with_type_status_and_code Location::S1, Order::SALE, Order::FINISHED, code
    assert_equal(2657, order.o_id)
  end

  def test_should_get_empty_order_with_error_if_the_code_is_invalid
    code = "XXX-XXXX"
    order = Order.new.get_orders_at_location_with_type_status_and_code Location::S1, Order::SALE, Order::FINISHED, code
    assert( order.empty? == true , "The order isn't empty or is not an order (nil?)")
    assert_equal [t.errors.inexistent_order.to_s, t.errors.invalid_order_id.to_s].flatten.join(": "), order.errors.to_a.flatten.join(": ")
  end

end
