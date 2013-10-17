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
  
end
