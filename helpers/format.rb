module Utils
  class << self
    def number_format number, dec, empty_replacement="-"
      if number.nil? or number == 0
        ret = empty_replacement
      else
        ret = sprintf("%0.#{dec}f", number.round(dec))
        ret = ret.gsub('.', ',') 
      end
      ret
    end

    def money_format number, dec
      num = number_format(number, dec)
      num = "$ #{num}" unless num == '-'
      num
    end

    def local_datetime_format time
      # TODO: DST support
      (time - (60 * 60 * 3)).strftime("%d/%m/%Y %H:%M") unless time.nil?
    end

    def local_date_format date
      date.strftime("%d/%m/%Y") unless date.nil?
    end
  end
end
