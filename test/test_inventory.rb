require_relative 'prerequisites'

class InventoryTest < Test::Unit::TestCase

  def test_should_get_all_bulks_in_location
    inv = Inventory.new(Location::W2)
    bulks = inv.bulks.all
    assert bulks.class == Array
    bulks.each {|bulk| assert bulk.class == Bulk}
  end

end
