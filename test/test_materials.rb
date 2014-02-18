require_relative 'prerequisites'

class MaterialTest < Test::Unit::TestCase

  def setup
    @material_params = {"_method"=>"put", "m_id"=>"2", "c_id"=>"2", "m_name"=>"Liquido corporal azul", "m_qty"=>"6272", "m_price"=>"0.001", "splat"=>[], "captures"=>["2"], "id"=>"2"}

    @valid_material = Material.new
    @valid_material.m_id = 1
    @valid_material.c_id = 8
    @valid_material.m_name = "Liquido corporal negro"
    @valid_material.created_at = "2013-07-19 02:52:24 -0300"
  end

  def test_string_stripper
    m = Material.new
    m.m_name = "    Test name    "
    assert_equal("Test name", m.m_name)
  end

  def test_should_create_material_ignoring_extra_params
    m = Material.new
    m.m_id = 1
    assert(m.changed_columns.include?(:m_id))

    @material_params[:m_name] = "Liquido corporal azul 2"
    m.update_from_hash( @material_params )
    assert_equal(2, m[:c_id])
    assert_equal("Liquido corporal azul 2", m[:m_name])

    assert(m.changed_columns.include?(:c_id))
    assert(m.changed_columns.include?(:m_name))

    assert_equal(3, m.changed_columns.size, "There are #{m.changed_columns.size} changes and should have 2")
    puts "\n" + m.errors.to_s if m.errors.size != 0
  end

  def test_should_reject_nil_name
    m = Material.new
    m.m_id = 1
    m.m_name = nil
    assert_equal(false, m.valid?, "The name can't be nil")
    
    assert_equal( [R18n.t.errors.presence], m.errors[:Nombre])
    puts "\n" + m.errors.to_s if m.errors.size != 1
  end

  def test_should_reject_empty_name
    m = Material.new
    m.m_id = 1
    m.m_name = ""
    assert_equal(false, m.valid?, "The name can't be empty")
    assert_equal( [R18n.t.errors.presence], m.errors[:Nombre])
    puts "\n" + m.errors.to_s if m.errors.size != 1
end

  def test_should_accept_interger_id
    m = Material.new
    m.m_name = "test name"

    10.times do
      id = (rand()*1000).floor+1
      m.m_id = id
      assert_equal(id, m.m_id)
      assert(m.valid?, "The id must be a possitive integer #{id} #{id.class} given")
      puts "\n" + m.errors.to_s if m.errors.size != 0
    end
  end

  def test_should_reject_negative_id
    m = Material.new
    m.m_id = -1
    m.m_name = "test name"
    assert_equal(-1, m.m_id)
    assert_equal(false, m.valid?, "The id can't be negative")
    assert_equal( [R18n.t.errors.positive_feedback(-1)], m.errors[:m_id])
    puts "\n" + m.errors.to_s if m.errors.size != 1
end

  def test_should_reject_zero_id
    m = Material.new
    m.m_id = 0
    m.m_name = "test name"
    assert_equal(0, m.m_id)
    assert_equal(false, m.valid?, "The id must be positive")
    assert_equal( [R18n.t.errors.positive_feedback(0)], m.errors[:m_id])
    puts "\n" + m.errors.to_s if m.errors.size != 1
  end

  def test_should_reject_nan_id
    m = Material.new
    m.m_name = "test name"
    m.m_id = "a"
    assert_equal(false, m.valid?, "The id must be numeric")
    puts "\n" + m.errors.to_s if m.errors.size != 1
  end

  def test_get_price
    price = Material.new.get_price 140
    assert price.class == BigDecimal
  end

  def test_should_get_same_price_regardless_of_location
    mat1 = Material.new.get_by_id 31, Location::W1
    mat2 = Material.new.get_by_id 31, Location::W2
    mat3 = Material.new.get_by_id 31, Location::S2
    assert_equal mat1[:m_price], mat2[:m_price]
    assert_equal mat1[:m_price], mat3[:m_price]
  end

  def test_should_create_new_material
    DB.transaction(rollback: :always) do
      begin
        mat = Material.new.create_default
      rescue Sequel::UniqueConstraintViolation => e
        assert_equal "Mysql2::Error: Duplicate entry '! NUEVO MATERIAL' for key 'm_name'", e.message
        mat = Material.filter(m_name: R18n.t.material.default_name).first
        mat.m_name = rand
        mat.save
        mat = Material.new.create_default
      end
      assert_equal mat.class, Fixnum
    end
  end

end
