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
    reports_products_to_buy settings.desired_months_worth_of_items_in_store
  end
  post '/reports/products_to_buy/months' do
    redirect to params[:months].nil? ? "/reports/products_to_buy" : "/reports/products_to_buy/#{params[:months].to_i}/months"
  end
  get '/reports/products_to_buy/:months/months' do
    reports_products_to_buy params[:months].to_i
  end
  def reports_products_to_buy months
    list = Product.new.get_list.where(tercerized: true, end_of_life: false).order(:categories__c_name, :products__p_name).all
    @products = Product.new.get_saleable_at_all_locations list
    @products.map do |product|
      product[:virtual_stock_store_1] = product.inventory(months).store_1.virtual
      product[:ideal_stock] = product.inventory(months).global.ideal
      product[:stock_deviation] = product.inventory(months).global.v_deviation
      product[:stock_deviation_percentile] = product.inventory(months).global.v_deviation_percentile
    end
    @products.sort_by! { |product| [ product.inventory(months).global.v_deviation_percentile, product.inventory(months).global.v_deviation ] }
    @products.delete_if { |product| product.inventory(months).global.v_deviation_percentile >= settings.reports_percentage_threshold}
    slim :reports_products_to_buy, layout: :layout_backend, locals: {title: R18n.t.reports_products_to_buy(months), sec_nav: :nav_administration, months: months}
  end

  get '/reports/materials_to_buy' do
    reports_materials_to_buy settings.desired_months_worth_of_bulk_in_warehouse
  end
  post '/reports/materials_to_buy/months' do
    redirect to params[:months].nil? ? "/reports/materials_to_buy" : "/reports/materials_to_buy/#{params[:months].to_i}/months"
  end
  get '/reports/materials_to_buy/:months/months' do
    reports_materials_to_buy params[:months].to_i
  end
  def reports_materials_to_buy months
    @materials = Material.new.get_list([Location::W1, Location::W2])
    @materials.map do |material|
      material.update_stocks
      material.recalculate_ideals months
    end
    @materials.sort_by! { |material| [ material[:stock_deviation_percentile], material[:stock_deviation] ] }
    @materials.delete_if { |material| material[:stock_deviation_percentile] >= settings.reports_percentage_threshold}
    slim :reports_materials_to_buy, layout: :layout_backend, locals: {title: R18n.t.reports_materials_to_buy(months), sec_nav: :nav_administration, months: months}
  end


  get '/reports/to_package/:mode' do
    list = Product.new.get_list.where(tercerized: false, end_of_life: false).order(:categories__c_name, :products__p_name)
    @products = Product.new.get_saleable_at_all_locations list
    months = 0
    @products.map do |product|
      case params[:mode].upcase
        when Product::STORE_ONLY_1, Product::ALL_LOCATIONS_1
          months = 1
        when Product::STORE_ONLY_2, Product::ALL_LOCATIONS_2
          months = 2
        when Product::STORE_ONLY_3, Product::ALL_LOCATIONS_3
          months = 3
      end

      if [Product::STORE_ONLY_1, Product::STORE_ONLY_2, Product::STORE_ONLY_3].include? params[:mode].upcase
        product[:virtual_stock_store_1] = product.inventory(months).store_1.virtual
        product[:ideal_stock] = product.inventory(months).store_1.ideal
        product[:stock_deviation] = product.inventory(months).store_1.v_deviation
        product[:stock_deviation_percentile] = product.inventory(months).store_1.v_deviation_percentile
      else
        product[:virtual_stock_store_1] = product.inventory(months).store_1.virtual
        product[:ideal_stock] = product.inventory(months).global.ideal
        product[:stock_deviation] = product.inventory(months).global.v_deviation
        product[:stock_deviation_percentile] = product.inventory(months).global.v_deviation_percentile
      end

    end
    if [Product::STORE_ONLY_1, Product::STORE_ONLY_2, Product::STORE_ONLY_3].include? params[:mode].upcase
      @products.sort_by! { |product| [ product.inventory(months).store_1.v_deviation_percentile, product.inventory(months).global.v_deviation ] }
      @products.delete_if { |product| product.inventory(months).store_1.v_deviation_percentile >= settings.reports_percentage_threshold}
    else
      @products.sort_by! { |product| [ product.inventory(months).global.v_deviation_percentile, product.inventory(months).global.v_deviation ] }
      @products.delete_if { |product| product.inventory(months).global.v_deviation_percentile >= settings.reports_percentage_threshold}
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
      product[:ideal_stock] = product.inventory.store_1.ideal
      product[:to_move] = BigDecimal.new(0)
      product[:to_move] = product.inventory.store_1.v_deviation * -1 unless product.inventory.store_1.virtual >= product.inventory.store_1.ideal
      stock_in_current_location = eval("product.inventory.#{current_location[:name].downcase}.stock")
      product[:to_move] = stock_in_current_location if product[:to_move] > stock_in_current_location
      if stock_in_current_location > 0 and (product.end_of_life or product.ideal_stock == 0)
        product[:stock_deviation] = stock_in_current_location * -1
        product[:stock_deviation_percentile] = -100
        product[:to_move] = stock_in_current_location
      end
      @products << product unless product[:to_move] == 0

    end
    @products.sort_by! { |product| [ product[:stock_deviation_percentile], product[:stock_deviation] ] }
    @products.delete_if { |product| product[:stock_deviation_percentile] >= settings.reports_percentage_threshold}
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
