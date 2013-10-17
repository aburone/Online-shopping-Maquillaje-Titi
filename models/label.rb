require_relative 'item'
class Label < Item
  def get_unprinted
    Item.filter(i_status: Item::NEW).order(:created_at)
  end

  def get_printed
    Label.filter(i_status: Item::PRINTED).order(:created_at)
  end

  def get_printed_by_id i_id
    i_id = i_id.to_s.strip
    label = get_printed.filter(i_id: i_id).first
    if label.nil?
      label = Label[i_id]
      if label.nil?
        message = "No tengo ninguna etiqueta con el id #{i_id}"
        # ActionsLog.new.set(msg: message, u_id: User.new.current_user_id, l_id: User.new.current_location[:name], lvl: ActionsLog::ERROR).save
        errors.add("Error general", message)
        return self
      end
      if label.i_status == Item::ASSIGNED
        message = "Este item (#{label.i_id}) ya esta asignado a #{label.p_name}"
        # ActionsLog.new.set(msg: message, u_id: User.new.current_user_id, l_id: User.new.current_location[:name], lvl: ActionsLog::ERROR, i_id: label.i_id, p_id: label.p_id).save
        errors.add("Error general", message)
      end
      if label.i_status == Item::VOID
        message = "Esta etiqueta fue anulada (#{label.i_id}). Tenias que haberla destruido"
        # ActionsLog.new.set(msg: message, u_id: User.new.current_user_id, l_id: User.new.current_location[:name], lvl: ActionsLog::ERROR, i_id: label.i_id).save
        errors.add("Error general", message)
      end
      if errors.count == 0
        # TODO: soy un pelotudo
        o_id = Item.select(:o_id).filter(i_id: i_id).join(:line_items, [:i_id]).first[:o_id]
        message = "No podes utilizar el item #{label.i_id} la orden actual por que esta en la orden #{o_id}"
        # ActionsLog.new.set(msg: message, u_id: User.new.current_user_id, l_id: User.new.current_location[:name], lvl: ActionsLog::ERROR, i_id: label.i_id).save
        errors.add("Error general", message)
      end
      return self
    else
      return label
    end
  end

  def get_as_csv
    labels = get_unprinted.all
    DB.transaction do
      labels.each { |label| label.change_status(Item::PRINTED, nil) }
    end
    out = ""
    labels.each do |label|
      out += sprintf "\"#{label.i_id}\",\"Vto: #{(label.created_at+2.years).strftime("%b %Y")}\"\n"
    end
    out
  end

  def create qty
    qty.to_i.times do
      DB.transaction do
        Item.insert() 
        last_i_id = DB.fetch( "SELECT @last_i_id" ).first[:@last_i_id]
        message = R18n.t.label.created
        ActionsLog.new.set(msg: message, u_id: User.new.current_user_id, l_id: User.new.current_location[:name], lvl: ActionsLog::NOTICE, i_id: last_i_id).save
      end 
    end
  end


end
