require 'sequel'
require_relative 'material'
require_relative '../helpers/sequel_binary'

class Bulk < Sequel::Model
  many_to_one :material, key: :m_id
  # plugin :validation_helpers
  # plugin :auto_validations

  UNDEFINED="UNDEFINED"
  NEW="NEW"
  IN_USE="IN_USE"
  EMPTY="EMPTY"
  VOID="VOID"
  STATUS = [UNDEFINED, NEW, IN_USE, VOID]
  SELECTABLE_STATUS = [NEW, IN_USE]

  def empty?
    return @values[:b_id].nil? ? true : false
  end

  def get_list warehouse_name
    begin
      Bulk.select(:b_id, :b_qty, :b_price, :b_status, :b_printed, :bulks__created_at, :b_loc )
          .left_join(:materials, [:m_id])
          .select_append{:m_name}
          .where(b_loc: warehouse_name)
          .order(:m_name, :bulks__created_at)
    rescue Exception => @e
      p @e
      return []
    end
  end

  def create m_id, b_price, warehouse_name
    b_price = BigDecimal.new b_price, 3
    DB.transaction do
      bulk = Bulk.new
      bulk[:m_id] = m_id.to_i
      bulk[:b_price] = sprintf("%0.#{3}f", b_price.round(3))
      bulk[:b_loc] = warehouse_name
      bulk[:b_status] = Bulk::NEW
      bulk.save validate: false
      last_b_id = DB.fetch( "SELECT @last_b_id" ).first[:@last_b_id]
      message = R18n.t.bulk.created
      ActionsLog.new.set(msg: message, u_id: User.new.current_user_id, l_id: User.new.current_location[:name], lvl: ActionsLog::INFO, b_id: last_b_id, m_id: m_id).save
    end
  end

  def get_by_id b_id
    begin
      Bulk.select(:b_id, :b_qty, :b_price, :b_status, :b_printed, :bulks__created_at )
          .left_join(:materials, [:m_id])
          .select_append{:m_name}
          .where(b_id: b_id)
          .first
    rescue Exception => @e
      p @e
      return [""]
    end
  end

  def get_unprinted location
    Bulk.select(:b_id, :m_id, :b_qty, :b_price, :b_status, :b_printed, :b_loc, :bulks__created_at)
      .left_join(:materials, [:m_id])
      .select_append{:m_name}
      .filter(b_printed: 0)
      .filter(b_loc: location.to_s)
      .order(:m_id)
  end

  def raise_if_changing_void current_user_id, current_location
    if @values[:b_status] == Bulk::VOID
      message = R18n.t.errors.modifying_status_of_void_bulk(@values[:b_id])
      ActionsLog.new.set(msg: message, u_id: current_user_id, l_id: current_location, lvl: ActionsLog::ERROR, m_id: @values[:m_id], b_id: @values[:b_id]).save
      raise message
    end
  end

  def change_status status, o_id
    o_id = o_id.to_i
    u = User.new
    current_user_id = u.current_user_id
    current_location = u.current_location[:name]    
    raise_if_changing_void current_user_id, current_location

    @values[:b_status] = status
    @values[:b_loc] = Location::UNDEFINED if status == Bulk::VOID
    save validate: false, columns: [:b_loc, :b_status]
    log = ActionsLog.new.set(msg: R18n.t.actions.changed_status(ConstantsTranslator.new(status).t), u_id: current_user_id, l_id: current_location, lvl: ActionsLog::INFO, m_id: @values[:m_id], b_id: @values[:b_id])
    log.set(o_id: o_id) unless o_id == 0
    log.save
    self
  end

  def set_as_printed
    u = User.new
    current_user_id = u.current_user_id
    current_location = u.current_location[:name]    
    raise_if_changing_void current_user_id, current_location

    @values[:b_printed] = 1
    save validate: false, columns: [:b_printed]
    message = "Granel marcado como impreso"
    log = ActionsLog.new.set(msg: message, u_id: current_user_id, l_id: current_location, lvl: ActionsLog::INFO, m_id: @values[:m_id], b_id: @values[:b_id])
    log.save
    self
  end

  def get_as_csv location
    labels = get_unprinted(location).all
    DB.transaction do
      labels.each do |label|
        labels.each { |label| label.set_as_printed }
      end
    end
    out = ""
    labels.each do |label|
      out += sprintf "\"#{label.b_id}\",\"#{label[:m_name]} (x #{Utils::number_format(label[:b_qty], 0)})\",\"Vto: #{(label.created_at+3.years).strftime("%b %Y")}\"\n"
    end
    out
  end

  def update_from_hash(hash_values)
    raise ArgumentError, t.errors.nil_params if hash_values.nil?
    wanted_keys = [ :b_qty, :b_price, :b_status ]
    hash_values.select { |key, value| self[key.to_sym]=value.to_s.gsub(',', '.') if wanted_keys.include? key.to_sym unless value.nil?}
    if (BigDecimal.new self[:b_qty]) < 0.01
      self[:b_qty] = 0
      self[:b_status] = Bulk::EMPTY
    end
    cast
    self
  end

  def validate
    super

    validates_schema_types [:b_id, :b_id]
    validates_schema_types [:m_id, :m_id]
    validates_schema_types [:b_price, :b_price]
    validates_schema_types [:b_qty, :b_qty]
    validates_schema_types [:b_status, :b_status]
    validates_schema_types [:created_at, :created_at]

    validates_exact_length 13, :b_id, message: "Malformed id #{b_id}"

    if self[:b_qty] == 0 and self[:b_status] != Bulk::EMPTY
      change_status(Bulk::EMPTY, nil)
    end
    if m_id.class != Fixnum
      errors.add("ID", "Debe ser numérico. #{m_id} (#{m_id.class}) dado" )
    else
      errors.add("ID", "Debe ser positivo. #{m_id} dado" ) unless m_id > 0
    end

    if b_price.class != BigDecimal
      errors.add("Precio", "Debe ser numérico. #{b_price} (#{b_price.class}) dado" )
    else
      errors.add("Precio", "Debe ser positivo. #{b_price.round(3).to_s("F")} dado" ) if b_price <= 0
    end

    if b_qty.class != BigDecimal
      errors.add("Cantidad", "Debe ser numérico. #{b_qty} (#{b_qty.class}) dado" )
    else
      errors.add("Cantidad", "Debe ser positivo o cero. #{b_qty.round(3).to_s("F")} dado" ) if b_qty < 0
    end
  end

  def to_s
    out = "\n"
    out += "#{self.class} #{sprintf("%x", self.object_id)}:\n"
    out += "\tb_id:    #{@values[:b_id]}\n"
    out += "\tm_id:  #{@values[:m_id]}\n"
    out += @values[:b_qty]   ? "\tb_qty:   #{sprintf("%d", @values[:b_qty])}\n"      : "\tb_qty: \n"
    out += @values[:b_price] ? "\tb_price: #{sprintf("%0.3f", @values[:b_price])}\n" : "\tb_price: \n"
    out += "\tstatus: #{@values[:b_status]}\n"
    out += "\tb_loc: #{@values[:b_loc]}\n"
    out += "\tcreated: #{@values[:created_at]}\n"
    out
  end

  private
    def cast
      self[:b_price] = BigDecimal.new self[:b_price]
      self[:b_qty] = BigDecimal.new self[:b_qty]
    end
end

