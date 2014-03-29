require 'sequel'

class Line_payment < Sequel::Model

  TYPE = {CASH: "CASH", CREDIT_NOTE: "CREDIT_NOTE"}

end
