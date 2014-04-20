
class Backend < AppController
  get '/administration' do
    slim :admin, layout: Thread.current.thread_variable_get(:layout), locals: {sec_nav: :nav_administration, title: t.administration.title}
  end
end
