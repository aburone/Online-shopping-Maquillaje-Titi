require 'sequel'

class Category < Sequel::Model
  one_to_many :products

  # def initialize(database)
  #   @database = database
  #   self
  # end

  # def get_by_id(id)
  #   @database.filter(c_id: id.to_i).first
  # end

  # def all
  #   @database.all
  # end


  # def find_categories
  #   all
  # end

  # def find_category
  #   get_by_id( params[:id].to_i )
  # end

end
