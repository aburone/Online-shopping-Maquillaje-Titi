class Backend < AppController

  get '/reports/markups' do
    @products = Product.new.get_list.order(:categories__c_name, :products__p_name).all
    @products.sort_by! { |product| product[:markup_deviation_percentile] }
    slim :products_list, layout: :layout_backend, locals: {title: "Reporte de markups", sec_nav: :nav_administration,
      can_edit: true, edit_link: :edit_product,
      full_row: true,
      price_pro_col: false,
      stock_col: false,
      real_markup_col: true,
      ideal_markup_col: true,
      markup_deviation_percentile_col: true,
      persistent_headers: true
    }
  end

  get '/reports/products_to_buy' do
    list = Product.new.get_list.where(tercerized: true).order(:categories__c_name, :products__p_name).all
    @products = Product.new.get_saleable_at_all_locations list
    @products.map do |product|
      product[:virtual_stock_store_1] = product.inventory.store_1.virtual
      product[:ideal_stock_calculated] = product.inventory.global.ideal
      product[:stock_deviation] = product.inventory.global.v_deviation
      product[:stock_deviation_percentile] = product.inventory.global.v_deviation_percentile
    end
    @products.sort_by! { |product| [ product.inventory.global.v_deviation_percentile, product.inventory.global.v_deviation ] }
    @products.delete_if { |product| product.inventory.global.v_deviation_percentile >= -33}
    slim :products_list, layout: :layout_backend, locals: {title: "Reporte de productos por comprar", sec_nav: :nav_administration,
      full_row: true,
      price_pro_col: false,
      stock_col: false,
      persistent_headers: true,
      multi_stock_col: true,
      use_virtual_stocks: true,
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
    slim :materials_list, layout: :layout_backend, locals: {title: "Reporte de materiales por comprar", sec_nav: :nav_administration,
      can_edit: false,
      persistent_headers: true,
      click_to_filter: true,
      caption: "Click en la categoria y despues tocar espacio para filtrar",
      multi_stock_col: true,
      stock_deviation_col: true
    }
  end

  get '/reports/to_package/:mode' do
    list = Product.new.get_list.where(tercerized: false).order(:categories__c_name, :products__p_name) 
    @products = Product.new.get_saleable_at_all_locations list
    @products.map do |product|

      case params[:mode].upcase
        when Product::STORE_ONLY_1, Product::ALL_LOCATIONS_1
          months = 1
        when Product::STORE_ONLY_2, Product::ALL_LOCATIONS_2
          months = 2
        when Product::STORE_ONLY_3, Product::ALL_LOCATIONS_3
          months = 3
      end
      product.inventory months

      if [Product::STORE_ONLY_1, Product::STORE_ONLY_2, Product::STORE_ONLY_3].include? params[:mode].upcase
        product[:virtual_stock_store_1] = product.inventory.store_1.virtual
        product[:ideal_stock_calculated] = product.inventory.store_1.ideal
        product[:stock_deviation] = product.inventory.store_1.v_deviation
        product[:stock_deviation_percentile] = product.inventory.store_1.v_deviation_percentile
      else
        product[:virtual_stock_store_1] = product.inventory.store_1.virtual
        product[:ideal_stock_calculated] = product.inventory.global.ideal
        product[:stock_deviation] = product.inventory.global.v_deviation
        product[:stock_deviation_percentile] = product.inventory.global.v_deviation_percentile
      end

    end
    if [Product::STORE_ONLY_1, Product::STORE_ONLY_2, Product::STORE_ONLY_3].include? params[:mode].upcase
      @products.sort_by! { |product| [ product.inventory.store_1.v_deviation_percentile, product.inventory.global.v_deviation ] }
      @products.delete_if { |product| product.inventory.store_1.v_deviation_percentile >= -33}
    else
      @products.sort_by! { |product| [ product.inventory.global.v_deviation_percentile, product.inventory.global.v_deviation ] }
      @products.delete_if { |product| product.inventory.global.v_deviation_percentile >= -33}
    end
    slim :products_list, layout: :layout_backend, locals: {title: "Reporte de productos por envasar", sec_nav: :nav_production,
      can_edit: false,
      full_row: true,
      price_pro_col: false,
      stock_col: false,
      multi_stock_col: true,
      use_virtual_stocks: true,
      stock_deviation_col: true,
      persistent_headers: true,
      click_to_filter: true,
      caption: "Click en la categoria o marca y despues tocar espacio para filtrar"
    }
  end

  get '/reports/to_move' do
    list = Product.new.get_list.order(:categories__c_name, :products__p_name) 
    products = Product.new.get_saleable_at_all_locations(list)
    @products = []
    products.map do |product|
      product[:stock_deviation] = product.inventory.store_1.v_deviation
      product[:stock_deviation_percentile] = product.inventory.store_1.v_deviation_percentile
      product[:ideal_stock_calculated] = product.inventory.store_1.ideal
      product[:to_move] = BigDecimal.new(0)
      product[:to_move] = product.inventory.store_1.v_deviation * -1 unless product.inventory.store_1.virtual >= product.inventory.store_1.ideal
      stock_in_current_location = eval("product.inventory.#{current_location[:name].downcase}.stock")
      product[:to_move] = stock_in_current_location if product[:to_move] > stock_in_current_location
      @products << product unless product[:to_move] == 0

    end
    @products.sort_by! { |product| [ product[:stock_deviation_percentile], product[:stock_deviation] ] }
    @products.delete_if { |product| product[:stock_deviation_percentile] >= -33}
    slim :products_list, layout: :layout_backend, locals: {title: "Reporte de productos por enviar desde #{current_location[:translation]} hacia Local 1", sec_nav: :nav_production,
      can_edit: false,
      full_row: false,
      price_pro_col: false,
      persistent_headers: true,
      multi_stock_col: true,
      use_virtual_stocks: true,
      stock_deviation_col: true,
      to_move_col: true,
      click_to_filter: true,
      caption: "Click en la categoria o marca y despues tocar espacio para filtrar"
    }
  end

end
