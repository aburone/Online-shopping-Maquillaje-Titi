class Location
  UNDEFINED="UNDEFINED"
  W1="WAREHOUSE_1"
  W2="WAREHOUSE_2"
  S1="STORE_1"
  S2="STORE_2"

  WAREHOUSES = [W1, W2]
  ENABLED_WAREHOUSES = WAREHOUSES
  STORES = [S1, S2]
  ENABLED_STORES = [S1]

  def warehouses
    translated_list ENABLED_WAREHOUSES
  end

  def stores
    translated_list ENABLED_STORES
  end

  def valid? location
    (ENABLED_WAREHOUSES + ENABLED_STORES).include? location
  end

  def store? location
    ENABLED_STORES.include? location
  end

  def warehouse? location
    ENABLED_WAREHOUSES.include? location
  end

  def get name
    if name.nil?
      current = {name: "", translation: ""}
    else
      current = {name: name, translation: ConstantsTranslator.new(name).t}
    end
    current
  end

  private
  def translated_list items
    list = []
    items.each do |name|
      current = get name
      list << current
    end
    list
  end

end
