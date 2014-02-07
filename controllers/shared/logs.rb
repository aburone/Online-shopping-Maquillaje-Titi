module Logs
  def get_logs
    if params.empty?
      art_date = Time.now.getlocal("-03:00").to_date.iso8601
      sub = Sequel.date_sub(art_date, {days:1})
      @logs = ActionsLog
                .select(:at, :msg, :lvl, :b_id, :m_id, :i_id, :p_id, :o_id, :u_id, :l_id, :username)
                .join(:users, user_id: :u_id)
                .where{Sequel.expr(:at) >= sub}
                .order(:id)
                .reverse
                .all
    else
      @logs = ActionsLog
      pp params
      params.each do |key, value|
        pp value.nil? or value.to_s.strip.empty?
        @logs = @logs.where( key.to_sym => value) if ["at", "msg", "lvl", "b_id", "m_id", "i_id", "p_id", "o_id", "u_id", "l_id"].include? key unless value.nil? or value.to_s.strip.empty?
      end
      @logs = @logs
                .limit(5000)
                .order(:id)
                .reverse
                .all
    end
    slim :logs, layout: Thread.current.thread_variable_get(:layout)
  end
end


class Backend < AppController
  include Logs
  get '/logs' do get_logs end
end

class Sales < AppController
  include Logs
  get '/logs' do get_logs end
end
