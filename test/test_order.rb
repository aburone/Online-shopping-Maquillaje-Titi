require_relative 'prerequisites'

class OrderTest < Test::Unit::TestCase

  def setup
  end

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

  def test_should_alter_inventory
  end

  def add_new_item order
    DB.transaction(rollback: :always) do
      label = get_printed_label
      Product.new.get_rand.add_item label, order.o_id
      item = Item[label.i_id]
      order.add_item(item)
    end
  end

end
