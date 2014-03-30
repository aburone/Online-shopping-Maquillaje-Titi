module Logs
  def get_logs
    if params.empty?
      @logs = ActionsLog.new.get_today
    else
      @logs = ActionsLog
      params.each do |key, value|
        @logs = @logs.where( key.to_sym => value) if ["at", "msg", "lvl", "b_id", "m_id", "i_id", "p_id", "o_id", "u_id", "l_id"].include? key unless value.nil? or value.to_s.strip.empty?
      end
      @logs = @logs
                .order(:id)
                .reverse
                .limit(500)
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
