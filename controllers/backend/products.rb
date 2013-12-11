class Backend < AppController

  get '/products/categories/?' do
    @categories = Category.all
    slim :categories, layout: :layout_backend
  end
  get '/products/categories/:id/?' do
    @category = Category[params[:id].to_i]
    slim :category, layout: :layout_backend
  end

  def void_items
    i_id = params[:i_id].to_s.strip
    item = Item.filter(i_id: i_id).first
    if item.nil?
      flash[:error] = "No tengo ningun item con el id #{i_id}"
      redirect to('/products/void_items')
    end

    begin
      message = item.void! params[:reason]
      flash.now[:notice] = message
      @title = message
      @item = item
      slim :void_item, layout: :layout_backend, locals: {sec_nav: :nav_products}
    rescue SecurityError => e
      flash[:error] = e.message
      redirect to('/products/void_items')
    rescue => e
      flash[:error] = e.message
      redirect to('/products/void_items')
    end
  end

  route :get, :post, '/products/void_items' do
    if params[:i_id].nil? and params[:reason].nil?
      slim :void_items, layout: :layout_backend, locals: {sec_nav: :nav_products} 
    else
      void_items
    end
  end

  get '/products/items/?' do
    @items = Item.new.get_list_at_location current_location[:name]
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
      puts product
      product = Product.new.get product.p_id
      product.save columns: Product::COLUMNS
      flash[:notice] = R18n.t.product.updated
    else
      flash[:error] = product.errors 
    end
    redirect to("/products/#{product[:p_id]}")
  end


  def edit_product p_id
    @product = Product.new.get p_id
    if @product.empty?
      flash[:error] = R18n.t.product.not_found
      redirect to("/products")
    end
    @categories = Category.all
    @brands = Brand.all
    @items =  @product.items
    unless params[:p_short_name].nil?
      puts params
      puts JSON.parse( params[:brand] )
    end
    slim :product, layout: :layout_backend
  end

end
