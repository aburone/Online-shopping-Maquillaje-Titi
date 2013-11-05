require_relative 'prerequisites'

class InventoryTest < Test::Unit::TestCase

  def test_should_get_all_bulks_in_location
    inv = Inventory.new(Location::W2)
    bulks = inv.bulks.all
    assert bulks.class == Array
    bulks.each {|bulk| assert bulk.class == Bulk}
  end

  def test_can_complete_order
    inv = Inventory.new(Location::W2)
    assert inv.can_complete_order? Order[20]
    # pp inv.needed_materials
    # pp inv.missing_materials
    # pp inv.used_bulks
  end
end