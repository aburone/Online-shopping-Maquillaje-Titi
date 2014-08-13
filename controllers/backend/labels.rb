class Backend < AppController

  get '/production/labels' do
    @labels = Label.new.get_unprinted.all
    @sec_nav = :nav_production
    slim :labels, layout: :layout_backend, locals: {sec_nav: :nav_production, title: t.labels.title}
  end
  get '/production/labels/list' do
    unprinted = Label.new.get_unprinted.all
    printed = Label.new.get_printed.all
    @labels = unprinted + printed
    @sec_nav = :nav_production
    slim :labels, layout: :layout_backend, locals: {sec_nav: :nav_production, title: t.labels.title}
  end
  post '/production/labels/csv/?' do
    require 'tempfile'
    barcodes = Label.new.get_as_csv
    tmp = Tempfile.new(["barcodes", ".csv"])
    tmp << barcodes
    tmp.close
    send_file tmp.path, filename: 'barcodes.csv', type: 'octet-stream', disposition: 'attachment'
    tmp.unlink
  end
  post '/production/labels/new' do
    Label.new.create params[:qty].to_i
    redirect to("/production/labels")
  end

end
