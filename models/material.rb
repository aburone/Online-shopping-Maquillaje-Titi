class Material < Sequel::Model(:materials)
  require_relative 'material_sql.rb'

  def perform
    begin
      self.calculate_ideal_stock
      self.save validate: false
      message = "Recalculando material #{self.m_id}: #{self.m_name}"
      ActionsLog.new.set(msg: message, u_id: User.new.current_user_id, l_id: Location::GLOBAL, lvl: ActionsLog::INFO, m_id: self.m_id).save

      self.validate
      if self.errors.count > 0
        message = "Error recalculando material #{self.m_id} #{self.m_name}: #{self.errors.to_a.flatten.join(" ")}"
        ActionsLog.new.set(msg: message[0..254], u_id: User.new.current_user_id, l_id: Location::GLOBAL, lvl: ActionsLog::ERROR, m_id: self.m_id).save
      end
    rescue => detail
      message = "Error critico: #{detail.message} #{$@}"
      ActionsLog.new.set(msg: message[0..254], u_id: User.new.current_user_id, l_id: Location::GLOBAL, lvl: ActionsLog::ERROR).save
    end
  end

  def name
    "#{self.m_id} #{self.m_name}"
  end

  def empty?
    return @values[:m_id].nil? ? true : false
  end

  def m_price= price
    self[:m_price] = price
  end

  def price_mod mod
    self[:old_buy_cost] = self.m_price.dup
    self.m_price *= mod
    self[:new_buy_cost] = self.m_price
  end

  def recalculate_ideals months
    self.m_ideal_stock *= months
    actual = @values[:m_qty].nil? ? BigDecimal.new(0) : @values[:m_qty]
    @values[:stock_deviation] = self.m_ideal_stock - actual
    @values[:stock_deviation] *= -1
    @values[:stock_deviation_percentile] = @values[:stock_deviation] * 100 / (self.m_ideal_stock)
    @values[:stock_deviation_percentile] = BigDecimal.new(0) if @values[:stock_deviation_percentile].nan?
  end

  def stock_deviation_percentile
    @values[:stock_deviation_percentile]
  end

  def update_from_hash(hash_values)
    wanted_keys = [ :m_name, :m_notes, :c_id, :SKU ]
    hash_values.select { |key, value| self[key.to_sym]=value if wanted_keys.include? key.to_sym unless value.nil?}

    numerical_keys = [ :m_ideal_stock, :m_price ]
    hash_values.select do |key, value|
      if numerical_keys.include? key.to_sym
        unless value.nil? or (value.class == String and value.length == 0)
          if Utils::is_numeric? value.to_s.gsub(',', '.')
            self[key.to_sym] = Utils::as_number value
          end
        end
      end
    end

    validate
    self
  end

end
