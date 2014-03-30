# coding: utf-8
require 'sequel'

class ActionsLog < Sequel::Model(:actions_log)
  plugin :validation_helpers
  INFO = 0
  NOTICE = 1
  WARN = 2
  ERROR = 3

  def perform
    self.save
  end

  def save (opts=OPTS)
    super opts
  end

  def validate
    super
    validates_presence :msg, message: "msg not given"
    validates_presence :u_id, message: "user not given"
    validates_integer :u_id
    validates_integer [:lvl, :m_id, :p_id], allow_nil: true
    validates_exact_length 12, :i_id, allow_nil: true
    validates_exact_length 13, :b_id, allow_nil: true
  end

  def print
    out = "\n"
    out += "#{self.class} #{sprintf("%x", self.object_id)}:\n"
    out += "\tat:   #{@values[:at]}\n"
    out += "\tmsg:  #{@values[:msg]}\n"
    out += "\tu_id: #{@values[:u_id]} #{@values[:u_id].class}\n"
    out += "\tlvl:  #{@values[:lvl]} #{@values[:lvl].class}\n"
    out += "\tb_id: #{@values[:b_id]} #{@values[:b_id].class}\n"
    out += "\tm_id: #{@values[:m_id]} #{@values[:m_id].class}\n"
    out += "\ti_id: #{@values[:i_id]} #{@values[:i_id].class}\n"
    out += "\to_id: #{@values[:o_id]} #{@values[:o_id].class}\n"
    out += "\tp_id: #{@values[:p_id]} #{@values[:p_id].class}\n"
    out += "\tl_id: #{@values[:l_id]} #{@values[:l_id].class}\n"
    echo out
  end

  def get_today
    ap Time.now.getlocal("-00:00")
    ap Time.now.getlocal("-03:00")
    ap Time.now.getlocal("-12:00")
    today = Sequel.date_sub(Time.now.getlocal("-12:00").to_date.iso8601, {days:1})
    ActionsLog
      .select(:at, :msg, :lvl, :b_id, :m_id, :i_id, :p_id, :o_id, :u_id, :l_id, :username)
      .join(:users, user_id: :u_id)
      .where{Sequel.expr(:at) >= today}
      .order(:id)
      .reverse
      .limit(500)
      .all
  end

end
