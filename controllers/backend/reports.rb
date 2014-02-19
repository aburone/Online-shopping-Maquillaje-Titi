class Backend < AppController

  get '/reports/markups' do
    @products = Product.new.get_list.order(:categories__c_name, :products__p_name).all
    @products.delete_if { |product| product[:markup_deviation_percentile].between? -10, 10 }
    @products.sort_by! { |product| product[:markup_deviation_percentile] }
    slim :products_list, layout: :layout_backend, locals: {title: "Reporte de markups", sec_nav: :nav_administration,
      can_edit: true, edit_link: :edit_product,
      full_row: true,
      price_pro_col: false,
      stock_col: false,
      real_markup_col: true,
      markup_deviation_percentile_col: true,
      persistent_headers: true
    }
  end

  get '/reports/products_to_buy' do
    list = Product.new.get_list.where(tercerized: true).order(:categories__c_name, :products__p_name).all
    @products = Product.new.get_saleable_at_all_locations list
    @products.sort_by! { |product| [ product[:stock_deviation_percentile], product[:stock_deviation] ] }
    @products.delete_if { |product| product[:stock_deviation_percentile] >= -33}
    slim :products_list, layout: :layout_backend, locals: {title: "Reporte de productos por comprar", sec_nav: :nav_administration,
      full_row: true,
      price_pro_col: false,
      stock_col: false,
      persistent_headers: true,
      multi_stock_col: true,
      stock_deviation_col: true,
      click_to_filter: true,
      caption: "Click en la categoria o marca y despues tocar espacio para filtrar"
    }
  end

  get '/reports/materials_to_buy' do
    @materials = Material.new.get_list([Location::W1, Location::W2])
    @materials.map { |m| m.update_stocks }
    @materials.sort_by! { |material| [ material[:stock_deviation_percentile], material[:stock_deviation] ] }
    @materials.delete_if { |material| material[:stock_deviation_percentile] >= -33}
    slim :materials_list, layout: :layout_backend, locals: {title: "Reporte de materiales por comprar (no terminado)", sec_nav: :nav_administration,
      can_edit: false,
      persistent_headers: true,
      click_to_filter: true,
      caption: "Click en la categoria y despues tocar espacio para filtrar",
      multi_stock_col: true,
      stock_deviation_col: true
    }
  end

  get '/reports/stocks' do
    list = Product.new.get_list.where(tercerized: false).order(:categories__c_name, :products__p_name) 
    @products = Product.new.get_saleable_at_all_locations list
    @products.sort_by! { |product| [ product[:stock_deviation_percentile], product[:stock_deviation] ] }
    @products.delete_if { |product| product[:stock_deviation_percentile] >= -33}
    slim :products_list, layout: :layout_backend, locals: {title: "Reporte de productos por envasar", sec_nav: :nav_production,
      can_edit: false,
      full_row: true,
      price_pro_col: false,
      stock_col: false,
      multi_stock_col: true,
      stock_deviation_col: true,
      persistent_headers: true,
      click_to_filter: true,
      caption: "Click en la categoria o marca y despues tocar espacio para filtrar"
    }
  end

  get '/reports/to_move' do
    list = Product.new.get_list.order(:categories__c_name, :products__p_name) 
    products = Product.new.get_saleable_at_all_locations(list)
    stock_location_name = "stock_#{current_location[:name].downcase}".to_sym
    @products = []
    products.map do |product| 
      product[:to_move] = 0
      product[:to_move] = product[:ideal_stock] - product[:stock_store_1] unless product[:stock_store_1] > product[:ideal_stock]
      product[:to_move] = product[stock_location_name] if product[:to_move] >= product[stock_location_name]
      @products << product unless product[:to_move] == 0
    end
    @products.sort_by! { |product| -product[:to_move] }

    slim :products_list, layout: :layout_backend, locals: {title: "Reporte de productos por enviar desde #{current_location[:translation]} hacia Local 1", sec_nav: :nav_production,
      can_edit: false,
      full_row: true,
      price_pro_col: false,
      persistent_headers: true,
      multi_stock_col: true,
      to_move_col: true,
      click_to_filter: true,
      caption: "Click en la categoria o marca y despues tocar espacio para filtrar"
    }
  end

end
