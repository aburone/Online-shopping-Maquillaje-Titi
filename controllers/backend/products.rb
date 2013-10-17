class Backend < AppController

  get '/products/categories/?' do
    @categories = Category.all
    slim :categories, layout: :layout_backend
  end
  get '/products/categories/:id/?' do
    @category = Category[params[:id].to_i]
    slim :category, layout: :layout_backend
  end

  get '/products/items/?' do
    @items = Item.new.get_list_at_location current_location[:name]
    slim :items, layout: :layout_backend, locals: {can_edit: true, sec_nav: :nav_products}
  end

  get '/products_relationships/?' do
    products = Product.new.get_list.all
    @relationships = []
    products.each do |p|
      relationship = {product: p, materials: p.materials, parts: p.parts}
      @relationships << relationship
    end
    slim :products_relations, layout: :layout_backend
  end

  get '/products/?' do
    @products = Product.new.get_list.all
    slim :products, layout: :layout_backend, locals: {can_edit: true, sec_nav: :nav_products}
  end

  get '/products/:id/?' do
    @product = Product[params[:id].to_i]
    @items =  @product.items
    slim :product, layout: :layout_backend
  end

end
