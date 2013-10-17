require_relative 'prerequisites'

class ItemTest < Test::Unit::TestCase

  def test_should_get_last_cash_audit
    r_id = BookRecord
      .select{max(:r_id).as(last_audit)}
      .where(type: "Caja inicial")
      .where(b_loc: Location::S1)
      .first[:last_audit]
    last = BookRecord.new.get_last_cash_audit Location::S1
    assert_equal r_id, last[:r_id]
  end

  def test_should_get_all_records_from_last_cash_audit
    records = BookRecord.new.from_last_audit Location::S1
    records.each {|record| assert_equal record.class, BookRecord }
  end

end
