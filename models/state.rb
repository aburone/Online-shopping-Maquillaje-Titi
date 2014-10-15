class State
  class << self
    attr_accessor :current_user
    attr_accessor :current_location

    def current_location_name
      current_location[:name]
    end

  end
end

