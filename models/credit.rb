require 'sequel'

class Credit < Sequel::Model

  def initialize(database)
    @database = database
    self
  end

  def get_by_id(id)
    @database.filter(credit_id: id.to_i).first
  end

  def all
    @database.all
  end

  def find_credits
    all
  end

  def find_credit
    get_by_id( params[:id].to_i )
  end

end
