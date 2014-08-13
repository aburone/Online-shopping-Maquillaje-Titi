require_relative 'prerequisites'

class InventoryTest < Test::Unit::TestCase

  def test_should_get_all_bulks_in_location
    inv = Inventory.new(Location::W2)
    bulks = inv.bulks.all
    assert bulks.class == Array
    bulks.each {|bulk| assert bulk.class == Bulk}
  end

  def test_assy
    # order = Order.new.get 16609
    # ap inventory.can_complete_order? order
    # ap inventory.used_bulks
    # ap inventory.missing_materials
    # ap inventory.errors

    # material = Material.new.get_by_id 21, User.new.current_location[:name]
m_id = 25

    inventory = Inventory.new(User.new.current_location[:name])
    ap inventory.material m_id

    inventory = Inventory.new(Location::S1)
    ap inventory.material m_id
    inventory = Inventory.new(Location::S2)
    ap inventory.material m_id

  end
end
