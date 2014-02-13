class Backend < AppController

  def void_items
    i_ids = Item.new.split_input_into_ids(params[:i_ids])
    items = Item.filter(i_id: i_ids).all
    errors = Item.new.check_io(i_ids, items)
    unless errors.empty?
      flash[:error] = "Algunos ID especificados son invalidos #{errors.flatten.to_s}"
      redirect to('/inventory/void_items')
      return false
    end

    begin
      messages = []

      items.each { |item| messages << item.void!(params[:reason]) }
      flash.now[:notice] = messages.flatten.to_s
      @title = "Anulacion correcta"
      @items = items
      slim :void_items, layout: :layout_backend, locals: {sec_nav: :nav_administration} 
    rescue SecurityError => e
      flash[:error] = e.message
      redirect to('/inventory/void_items')
    rescue => e
      flash[:error] = e.message
      redirect to('/inventory/void_items')
    end
  end

  route :get, :post, '/inventory/void_items' do
    if params[:i_ids].nil? and params[:reason].nil?
      slim :void_items, layout: :layout_backend, locals: {sec_nav: :nav_administration} 
    else
      void_items
    end
  end


  get '/products/categories/?' do
    @categories = Category.all
    slim :categories, layout: :layout_backend
  end
  get '/products/categories/:id/?' do
    @category = Category[params[:id].to_i]
    slim :category, layout: :layout_backend
  end



  get '/products/items/?' do
    @items = Item.new.get_items_at_location current_location[:name]
    slim :items, layout: :layout_backend, locals: {can_edit: true, sec_nav: :nav_products}
  end

  get '/products_relationships/?' do
    products = Product.new.get_list.order(:c_name, :p_name).all
    @relationships = []
    products.each do |p|
      relationship = {product: p, materials: p.materials, parts: p.parts}
      @relationships << relationship
    end
    slim :products_relations, layout: :layout_backend
  end

  get '/products/?' do
    @products = Product.new.get_saleable_at_location(current_location[:name]).order(:c_name, :p_name).all
    slim :products, layout: :layout_backend, locals: {stock_col: true, full_row:true, can_edit: true, edit_link: :edit_product, sec_nav: :nav_products}
  end

  post '/products/new/?' do
    begin
      p_id = Product.new.create_default
      flash[:notice] = R18n.t.product.created
      redirect to("/products/#{p_id}")
    rescue Sequel::UniqueConstraintViolation => e
      puts e.message
      product = Product.filter(p_name: "NEW Varias").first
      flash[:warning] = R18n.t.product.there_can_be_only_one_new
      redirect to("/products/#{product[:p_id]}")
    end
  end

  get '/products/:id/?' do
    edit_product params[:id].to_i
  end

  put '/products/:id/?' do
    product = Product[params[:id].to_i].update_from_hash(params)
    if product.valid?
      product.save()
      product = Product.new.get product.p_id
      product.save columns: Product::COLUMNS
      flash[:notice] = R18n.t.product.updated
    else
      flash[:error] = product.errors 
    end
    redirect to("/products/#{product[:p_id]}")
  end

  post '/products/:id/dup' do
    product = Product[params[:id].to_i]
    if product.valid?
      dest = product.duplicate
      flash[:notice] = R18n.t.product.duplicated
    else
      flash[:error] = product.errors 
    end
    redirect to("/products/#{dest[:p_id]}")
  end

  put '/products/:p_id/materials' do
    p_id = params[:p_id].to_i
    product = Product[p_id]
    redirect_if_nil_product product, p_id, "/products"
    m_id = params[:m_id].to_i
    m_qty = params[:m_qty].to_s.gsub(',', '.').to_f
    material = Material[m_id]
    material[:m_qty] = m_qty
    redirect_if_nil_material material, m_id, "/products/#{p_id}"

    product.update_material material
    redirect_if_nil_product product, p_id, "/products/#{p_id}"

    flash[:notice] = t.product.material_updated material[:m_qty], material[:m_name] if material[:m_qty] > 0
    flash[:notice] = t.product.material_removed material[:m_name] if material[:m_qty] == 0
    redirect to("/products/#{product[:p_id]}#materials")
  end

  post '/products/:p_id/materials/add' do
    p_id = params[:p_id].to_i
    product = Product[p_id]
    redirect_if_nil_product product, p_id, "/products"
    m_id = params[:m_id].to_i
    m_qty = params[:m_qty].to_s.gsub(',', '.').to_f
    material = Material[m_id]
    material[:m_qty] = m_qty
    redirect_if_nil_material material, m_id, "/products/#{p_id}"

    product.add_material material
    redirect_if_nil_product product, p_id, "/products/#{p_id}"

    flash[:notice] = t.product.material_added material[:m_qty], material[:m_name]
    redirect to("/products/#{product[:p_id]}#materials")
  end


  put '/products/:p_id/parts' do
    p_id = params[:p_id].to_i
    product = Product[p_id]
    redirect_if_nil_product product, p_id, "/products"
    part_id = params[:part_id].to_i
    part_qty = params[:part_qty].to_s.gsub(',', '.').to_f
    part = Product[part_id]
    part[:part_qty] = part_qty
    redirect_if_nil_product part, part_id, "/products/#{p_id}"

    product.update_part part
    redirect_if_nil_product product, p_id, "/products/#{p_id}"

    flash[:notice] = t.product.part_updated part[:part_qty], part[:p_name] if part[:part_qty] > 0
    flash[:notice] = t.product.part_removed part[:p_name] if part[:part_qty] == 0
    redirect to("/products/#{product[:p_id]}#parts")
  end

  post '/products/:p_id/parts/add' do
    p_id = params[:p_id].to_i
    product = Product[p_id]
    redirect_if_nil_product product, p_id, "/products"

    part_id = params[:part_id].to_i
    part_qty = params[:part_qty].to_s.gsub(',', '.').to_f
    part = Product[part_id]
    part[:part_qty] = part_qty
    redirect_if_nil_product part, p_id, "/products/#{p_id}"

    product.add_part part
    redirect_if_nil_product product, p_id, "/products/#{p_id}"

    flash[:notice] = t.product.part_added part[:part_qty], part[:p_name]
    redirect to("/products/#{product[:p_id]}#materials")
  end


  def edit_product p_id
    @product = Product.new.get(p_id)
    if @product.empty?
      flash[:error] = R18n.t.product.not_found
      redirect to("/products")
    end
    @materials = Material.order(:m_name).all
    @parts = Product.all

    @p_parts = @product.parts
    @p_materials = @product.materials

    @categories = Category.all
    @brands = Brand.all
    slim :product, layout: :layout_backend
  end

end
