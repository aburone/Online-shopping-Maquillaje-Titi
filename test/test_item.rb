require_relative 'prerequisites'

class ItemTest < Test::Unit::TestCase

  def setup
    @valid_item = Item.new
    @valid_item.i_id = (rand * 1000).to_s[0..11]
    @valid_item.p_id = 1234
    @valid_item.p_name = "un nombre"
    @valid_item.i_status = Item::ASSIGNED
    @valid_item.i_loc = Location::W1
    @valid_item.i_price = 10
    @valid_item.i_price_pro = 8
    @valid_item.created_at = Time.now
  end

  def test_should_use_binary_search
    i_id = Item.first.i_id
    assert_false Item[i_id].empty?
    assert Item[i_id.to_i].nil?
  end

  def test_valid_item
    item = @valid_item
    assert(item.valid?)
  end

  def test_should_reject_empty_name
    item = @valid_item
    item.p_name = ""
    assert_false item.valid?
  end

  def test_should_reject_zero_p_id
    item = @valid_item
    item.p_id = 0
    assert_false item.valid?
  end

  def test_should_reject_nil_p_id
    item = @valid_item
    item.p_id = nil
    assert_false item.valid?
  end

  def test_should_reject_empty_status
    item = @valid_item
    item.i_status = ""
    assert_false item.valid?
  end

  def test_should_reject_negative_price
    item = @valid_item
    item.i_price = -1
    assert_false item.valid?
  end

  def test_should_reject_negative_price_pro
    item = @valid_item
    item.i_price_pro = -1
    assert_false item.valid?
  end

  def test_should_dissociate
    DB.transaction(rollback: :always) do
      item = get_assigned_item
      item = item.dissociate
      defaults = Item
                  .select(:i_id)
                  .select_append{default(:p_id).as(p_id)}
                  .select_append{default(:p_name).as(p_name)}
                  .select_append{default(:i_price).as(i_price)}
                  .select_append{default(:i_price_pro).as(i_price_pro)}
                  .select_append{default(:i_status).as(i_status)}
                  .select_append{default(:i_loc).as(i_loc)}
                  .first

      assert_equal item.p_id, defaults[:p_id]
      assert_equal item.p_name, defaults[:p_name]
      assert_equal item.i_price, defaults[:i_price]
      assert_equal item.i_price_pro, defaults[:i_price_pro]
      assert_equal item.i_status, Item::PRINTED
      assert_equal item.i_loc, defaults[:i_loc]
    end
  end

  def test_change_status_of_void_item_should_fail
    DB.transaction(rollback: :always) do
      item = Item.new.get_rand
      item[:i_status] = Item::VOID
      assert_raise SecurityError do
        item.change_status Item::READY, 0
      end
    end
  end  

  def test_manual_void_must_invalidate_location
    DB.transaction(rollback: :always) do
      item = Item.new.get_rand
      origin = item.i_loc.dup
      item.void! "Testing Item::void!"
      assert_equal Location::VOID, item.i_loc
      assert_equal Item::VOID, item.i_status
      order = Order.last
      assert_equal origin, order.o_loc
      assert_equal Location::VOID, order.o_dst
      assert_equal Order::FINISHED, order.o_status
    end
  end

  def test_manual_void_must_create_invalidation_order
    DB.transaction(rollback: :always) do
      auto_increment = DB.fetch('SHOW TABLE STATUS LIKE "orders"').first[:Auto_increment]
      item = Item.new.get_rand
      item.void! "Testing Item::void!"
      order = Order.last
      assert_equal auto_increment, order.o_id
      assert_equal Order::INVALIDATION, order.type
      assert_equal Order::FINISHED, order.o_status
    end
  end

  def test_manual_void_add_item_to_invalidation_order
    DB.transaction(rollback: :always) do
      item = Item.new.get_rand
      item.void! "Testing Item::void!"
      order = Order.last
      assert_equal 1, order.items.count
      assert_equal Order::FINISHED, order.o_status
    end
  end

  def test_manual_void_must_ask_reason
    DB.transaction(rollback: :always) do
      item = Item.new.get_rand
      assert_raise ArgumentError do
        item.void! "     "
      end
    end
  end

  def test_manual_void_reason_cant_be_shorter_than_5_chars
    DB.transaction(rollback: :always) do
      item = Item.new.get_rand
      assert_raise ArgumentError do
        item.void! "1234"
      end
    end
  end

  def test_manual_void_reason_must_be_at_least_5_chars
    DB.transaction(rollback: :always) do
      item = Item.new.get_rand
      item.void! "12345"
    end
  end

  def test_manual_void_should_not_allow_vod_a_voided_item
    DB.transaction(rollback: :always) do
      item = Item.new.get_rand
      item.void! "12345"
      assert_raise SecurityError do
        item.void! "12345"
      end
    end
  end

  def test_add_random_item_to_store_1
    label = get_printed_label
    product = Product.new.get_rand
    assigned_msg = product.add_item(label, nil)
    assert_equal R18n::t.label.assigned(label.i_id, product.p_name), assigned_msg
    label[:i_loc] = Location::S1
    label.change_status(Item::READY, 0)
  end

  def test_split
    input = "
     \t348-fba3ee06
    348-fc1d5f02
    351-2c9e4d19 
    "
    assert_equal ["348-fba3ee06", "348-fc1d5f02", "351-2c9e4d19"], Item.new.split_input_into_ids(input)
  end

  def test_multi_check
    i1 = Item.new.get_rand
    i2 = Item.new.get_rand
    input = "
     \t#{i1.i_id}
    #{i2.i_id}
    351-2c9e4d19INVALID 
    "
    i_ids = Item.new.split_input_into_ids(input)
    items = Item.filter(i_id: i_ids).all
    assert_equal ["351-2c9e4d19INVALID"], Item.new.check_io(i_ids, items)

    input = "
     \t348-fba3ee06
    348-fc1d5f02
    351-2c9e4d19
    "
    i_ids = Item.new.split_input_into_ids(input)
    items = Item.filter(i_id: i_ids).all
    assert Item.new.check_io i_ids, items
  end

  def test_transmute_item_should_not_allow_empty_reason
    item = Item.new.get_rand
    assert_raise ArgumentError do
      item.transmute!("", 5) # empty reason
    end
  end

  def test_transmute_item_should_not_allow_invalid_product
    item = Item.new.get_rand
    p_id = 6464564
    err = assert_raise ArgumentError do item.transmute!("Setting invalid product", p_id) end
    assert_equal R18n.t.product.missing(p_id).to_s, err.to_s
  end

  def test_transmute_item_should_not_allow_archived_product
    item = Item.new.get_rand
    p_id = 23
    err = assert_raises ArgumentError do item.transmute!("Setting archived product", p_id) end
    assert_equal R18n.t.product.errors.archived.to_s, err.to_s
  end

  def test_should_transmute_item
    # DB.transaction(rollback: :always) do
      item = Item.new.get_rand
      product = Product.new.get_rand
      item.transmute!("test_should_transmute_item", product.p_id) 
      assert_equal product.p_id, item.p_id
      assert_equal product.p_name, item.p_name
      assert_equal product.price, item.i_price
      assert_equal product.price_pro, item.i_price_pro
    # end
  end

end
