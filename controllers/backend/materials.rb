class Backend < AppController

  get '/materials' do
    @materials = Material.new.get_list(current_location[:name])
    slim :materials, layout: :layout_backend
  end
  post '/materials/new' do
    begin
      m_id = Material.new.create_default
      flash[:notice] = R18n.t.material.created
      redirect to("/materials/#{m_id}")
    rescue Sequel::UniqueConstraintViolation => e
      puts e.message
      material = Material.filter(m_name: R18n.t.material.default_name).first
      flash[:warning] = R18n.t.material.there_can_be_only_one_new
      redirect to("/materials/#{material[:m_id]}")
    end
  end
  get '/materials/:id' do
    @material = Material.new.get_by_id params[:id].to_i, current_location[:name]
    redirect_if_nil_material @material, params[:id].to_i, "/materials"
    @material.calculate_ideal_stock
    @materials_categories = MaterialsCategory.all
    @bulks = @material.bulks current_location[:name]
    @products = @material.products
    slim :material, layout: :layout_backend
  end
  put '/materials/:id' do
    material = Material[params[:id].to_i]
    material.update_from_hash(params)
    if material.valid?
      material.save();
      flash[:notice] = t.material.updated
    else
      flash[:error] = material.errors
    end
    redirect to("/materials/#{material[:m_id]}")
  end
  post '/materials/update_ideal_stocks' do
    Thread.new do
      Material.all.each { |m| m.calculate_ideal_stock }
    end
    flash[:warning] = "Actualizando materiales en background. La tarea tarda aproximadamente 2 minutos"
    redirect to("/materials")
  end

  get '/bulks' do
    @bulks = Bulk.new.get_bulks_at_location(current_location[:name]).order(:m_name).all
    @count = 0
    @bulks.map { |bulk| @count += 1 unless bulk.b_printed }
    slim :bulks, layout: :layout_backend
  end
  post '/bulks/labels/csv' do
    require 'tempfile'
    barcodes = Bulk.new.get_as_csv current_location[:name]
    tmp = Tempfile.new(["barcodes", ".csv"])
    tmp << barcodes
    tmp.close
    send_file tmp.path, filename: 'bulks.csv', type: 'octet-stream', disposition: 'attachment'
    tmp.unlink
  end

  get '/bulks/:b_id' do
    @bulk = Bulk[params[:b_id]]
    @material = @bulk.material if @bulk
    slim :bulk, layout: false
  end
  put '/bulks/:b_id' do
    bulk = Bulk[params[:b_id]].update_from_hash(params)
    if bulk.valid?
      bulk.save()
      flash[:notice] = t.bulk.updated
      redirect to("/materials/#{bulk[:m_id]}")
    else
      flash[:error] = bulk.errors 
      redirect to("/materials/#{bulk[:m_id]}")
    end
  end
  post '/bulks/new' do
    Bulk.new.create params[:m_id].to_i, Material.new.get_price(params[:m_id].to_i), current_location[:name]
    redirect to("/materials/#{params[:m_id].to_i}")
  end
end
