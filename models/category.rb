require 'sequel'

class Category < Sequel::Model
  one_to_many :products

  def update_from_hash hash_values
    raise ArgumentError, t.errors.nil_params if hash_values.nil?

    alpha_keys = [ :c_name, :description ]
    hash_values.select { |key, value| self[key.to_sym]=value.to_s if alpha_keys.include? key.to_sym unless value.nil?}

    checkbox_keys = [ :c_published ]
    checkbox_keys.each { |key| self[key.to_sym] = hash_values[key].nil? ? 0 : 1 }

    self
  end

  def empty?
    return !!!@values[:c_id]
  end

  def get_by_id c_id
     c_id = c_id.to_i
     category = Category[c_id]
     category = Category.new if category.nil?
     category
  end
end
