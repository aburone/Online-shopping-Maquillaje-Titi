# coding: utf-8

class Frontend < AppController
  set :name, "Frontend"
  helpers ApplicationHelper
  # aggresive caching for frontend
  set :start_time, Time.now
  before do
    last_modified settings.start_time
    etag settings.start_time.to_s
    cache_control :public, :must_revalidate
  end
    
  get '/' do
    slim :home, layout: :layout_frontend
  end

  get '/contacto/' do
    slim :contacto, layout: :layout_frontend
  end

  get '/fotos/' do
    slim :fotos, layout: :layout_frontend
  end

  get '/productos/' do
    @categories = Category.all
    slim :categorias, layout: :layout_frontend
  end

  get '/productos/:id' do
    @category = Category[params[:id].to_i]
    slim :categoria, layout: :layout_frontend
  end

end