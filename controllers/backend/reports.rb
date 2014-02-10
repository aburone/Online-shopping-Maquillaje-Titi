class Backend < AppController

  get '/reports/markups' do
    @products = Product.new.get_list
    slim :products_list, layout: :layout_backend, locals: {title: "Reporte de markups", sec_nav: :nav_administration,
      can_edit: true, edit_link: :edit_product,
      full_row: true,
      price_pro_col: false,
      stock_col: false,
      real_markup_col: true,
      markup_deviation_col: true,
      persistent_headers: true
    }
  end

  get '/reports/to_buy' do
    list = Product.new.get_list.where(tercerized: true)
    @products = Product.new.get_saleable_at_all_locations list
    slim :products_list, layout: :layout_backend, locals: {title: "Reporte de productos por comprar (no terminado)", sec_nav: :nav_administration,
      can_edit: true, edit_link: :edit_product,
      full_row: true,
      price_pro_col: false,
      stock_col: false,
      persistent_headers: true,
      multi_stock_col: true,
      stock_deviation_col: true
    }
  end

  get '/reports/stocks' do
    list = Product.new.get_list.where(tercerized: false)
    @products = Product.new.get_saleable_at_all_locations list
    slim :products_list, layout: :layout_backend, locals: {title: "Reporte de productos por envasar", sec_nav: :nav_production,
      can_edit: false,
      full_row: true,
      price_pro_col: false,
      stock_col: false,
      multi_stock_col: true,
      stock_deviation_col: true,
      persistent_headers: true
    }
  end

  get '/reports/to_move' do
    list = Product.new.get_list
    products = Product.new.get_saleable_at_all_locations list
    stock_location_name = "stock_#{current_location[:name].downcase}".to_sym
    @products = []
    products.map do |product| 
      product[:to_move] = 0
      product[:to_move] = product[:ideal_stock] - product[:stock_store_1] unless product[:stock_store_1] > product[:ideal_stock]
      product[:to_move] = product[stock_location_name] if product[:to_move] >= product[stock_location_name]
      @products << product
    end

    slim :products_list, layout: :layout_backend, locals: {title: "Reporte de productos por enviar al local 1 (no terminado)", sec_nav: :nav_production,
      can_edit: false,
      full_row: true,
      price_pro_col: false,
      persistent_headers: true,
      multi_stock_col: true,
      to_move_col: true
    }
  end

end
