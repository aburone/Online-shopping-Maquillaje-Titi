class Backend < AppController
  get '/production' do
    slim :admin, layout: Thread.current.thread_variable_get(:layout), locals: {sec_nav: :nav_production, title: t.production.title}
  end


end
