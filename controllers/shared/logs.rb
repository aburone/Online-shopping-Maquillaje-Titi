module Logs
  def get_and_render_logs
    if params.empty?
      render_logs ActionsLog.new.get_today
    else
      render_logs ActionsLog.new.get_with_hash params
    end
  end

  def get_and_render_logins username
    begin
      log_data = ActionsLog.new.get_logins(username)
    rescue SecurityError => e
      flash.now[:error] = e.message
      log_data = []
    end
    render_logs log_data
  end

  def render_logs log_data
    slim :logs, layout: Thread.current.thread_variable_get(:layout), locals: {logs: log_data}

  end
end


class Backend < AppController
  include Logs
  get '/logs' do get_and_render_logs end
end

class Sales < AppController
  include Logs
  get '/logs' do get_and_render_logs end
end
