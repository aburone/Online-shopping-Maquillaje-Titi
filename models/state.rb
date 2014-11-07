class State
  class << self
    @current_user = nil
    @current_location = nil
    SYSTEM_LOCATION = {name: "SYSTEM", translation: "Interna"}


    def current_user
      ap "user " + @current_user.username
      @current_user
    end
    def current_user= new_user
      @current_user = new_user
    end

    def current_location
      @current_location = SYSTEM_LOCATION if @current_location.nil?
      ap "location " + @current_location[:translation]
      @current_location
    end
    def current_location= new_location
      @current_location = new_location
    end

    def current_location_name
      @current_location = SYSTEM_LOCATION if @current_location.nil?
      ap "loation name " + @current_location[:name]
      @current_location[:name]
    end

  end
end

