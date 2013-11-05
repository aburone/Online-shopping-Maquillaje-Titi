class Inventory
  attr_reader :location, :needed_materials, :missing_materials, :used_bulks, :errors
  def initialize location
    @location = location
    @user_id = User.new.current_user_id
    @needed_materials = []
    @missing_materials = []
    @used_bulks = []
    @errors = []
  end

  def bulks status = :all
    Bulk.new.get_list(@location)
  end

  def can_complete_order? order
    return process_packaging_order(order, false)
  end

  def process_packaging_order order, must_save=true
    raise TypeError, 'Inexistent order' if order.nil?
    o_id = order.o_id
    DB.transaction do
      @missing_materials = []
      @used_bulks = []
      u = User.new
      current_user_id  = u.current_user_id
      current_location = u.current_location[:name]

      fill_needed_materials_and_give_me_a_copy(order).each do |material|
        get_needed_bulks(material).each do |bulk| 
          @used_bulks << bulk
          starting_b_qty = bulk[:b_qty].dup
          starting_m_qty = material[:m_qty].dup
          if bulk[:b_qty] >= material[:m_qty]
            bulk[:b_qty] -= material[:m_qty]
            material[:m_qty] = 0
          else
            material[:m_qty] -= bulk[:b_qty]
            bulk[:b_qty] = 0
          end
          if must_save
            qty = sprintf("%0.3f", (starting_b_qty - bulk[:b_qty]).round(3))
            message = "Utilizando #{qty} #{bulk[:m_name]}"
            ActionsLog.new.set(msg: message, u_id: current_user_id, l_id: current_location, lvl:  ActionsLog::NOTICE, b_id: bulk.b_id, m_id: bulk.m_id, o_id: o_id).save      
            bulk.change_status(Bulk::EMPTY, o_id) if bulk[:b_qty] == 0
            bulk.save columns: [:b_qty] 
          end
        end
        raise R18n::t.production.packaging_order.missing_materials_cant_allocate if must_save and (material[:m_qty] > 0)
        @missing_materials << material if material[:m_qty] > 0
      end
      if must_save 
        order.items.each do |item|
          message = "Materias primas restadas del inventario. Producto terminado"
          ActionsLog.new.set(msg: message, u_id: current_user_id, l_id: current_location, lvl:  ActionsLog::NOTICE, i_id: item.i_id, o_id: o_id).save
          add_item(item, o_id)
        end
        order.change_status Order::FINISHED
      end
    end
    return @missing_materials.empty? ? true : false
  end

  def process_inventory_order order
    o_id = order.o_id
    messages = []
    DB.transaction do
      u = User.new
      current_user_id  = u.current_user_id
      current_location = u.current_location[:name]

      order.items.each do |item|
        item.i_status = Item::READY
        item.i_loc = current_location
        item.save
        message = "Item #{item[:p_name]} agregado al stock del Local 1"
        ActionsLog.new.set(msg: message, u_id: current_user_id, l_id: current_location, lvl:  ActionsLog::NOTICE, i_id: item.i_id, o_id: o_id, p_id: item.p_id).save
        messages << message
        p message
        puts item
      end
    end
    messages
  end

  def add_item item, o_id
    message = "#{item[:p_name]} agregado al inventario}"
    ActionsLog.new.set(msg: message, u_id: @user_id, l_id: @location, lvl:  ActionsLog::NOTICE, i_id: item.i_id, p_id: item.p_id, o_id: o_id).save
    item.i_loc = @location
    item.change_status Item::READY, o_id
  end

  private
    def get_needed_bulks material
      Bulk
        .select(:b_id, :m_id, :b_qty, :b_price, :b_status, :b_loc, :bulks__created_at)
        .select_append(:m_name)
        .filter(b_loc: @location, m_id: material.m_id, b_status: Bulk::IN_USE)
        .join(:materials, [:m_id])
        .order(:b_qty)
        .all
    end

    def fill_needed_materials_and_give_me_a_copy order
      @needed_materials = []
      @needed_materials = order.materials
      aux = []
      @needed_materials.each { |n| aux << Utils::deep_copy(n) }
      aux
    end
end
