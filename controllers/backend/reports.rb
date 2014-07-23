class Backend < AppController

  get '/administration/reports/price_list' do
    @products = Product.new.get_live.order(:categories__c_name, :products__p_name).all
    slim :products_list, layout: :layout_backend, locals: {title: "Lista de precios", sec_nav: :nav_administration,
      status_col: true,
      can_filter: false
    }
  end

  route :get, '/administration/reports/logins/:username' do
    get_and_render_logins params[:username]
  end

  get '/administration/reports/products_flags' do
    @products = Product.new.get_all.order(:categories__c_name, :products__p_name).all
    slim :products_list, layout: :layout_backend, locals: {title: "Reporte de flags", sec_nav: :nav_administration,
      can_edit: true, edit_link: :edit_product,
      price_col: true,
      price_pro_col: false,
      stock_col: false,
      price_updated_at_col: true,
      flags_cols: true
    }
  end

  get '/administration/reports/markups' do
    @products = Product.new.get_live.order(:categories__c_name, :products__p_name).all
    @products.sort_by! { |product| product[:markup_deviation_percentile] }
    slim :products_list, layout: :layout_backend, locals: {title: "Reporte de markups", sec_nav: :nav_administration,
      can_edit: true, edit_link: :edit_product,
      price_pro_col: false,
      stock_col: false,
      real_markup_col: true,
      ideal_markup_col: true,
      markup_deviation_percentile_col: true,
      price_updated_at_col: true
    }
  end

  get '/production/reports/to_package/:mode' do
    list = Product.new.get_all_but_archived.where(tercerized: false, end_of_life: false).order(:categories__c_name, :products__p_name)
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
      can_hide: true,
      full_row: true,
      price_pro_col: false,
      stock_col: false,
      multi_stock_col: true,
      use_virtual_stocks: true,
      stock_deviation_col: true,
    }
  end


  route :get, :post, '/administration/reports/products_to_buy' do
    months = params[:months].to_i unless params[:months].nil? || params[:months] == 0
    months ||= settings.desired_months_worth_of_items_in_store
    reports_products_to_buy months
  end
  def reports_products_to_buy months
    list = Product.new.get_all_but_archived.where(tercerized: true, end_of_life: false).order(:categories__c_name, :products__p_name).all
    @products = Product.new.get_saleable_at_all_locations list
    @products.delete_if { |product| product.inventory(months).global.v_deviation_percentile >= settings.reports_percentage_threshold}

    distributors = Distributor.all
    distributors.map do |distributor|
      distributor[:stock_deviation] = 0
      distributor[:ideal_stock] = 0
      distributor[:ponderated_deviation] = 0
    end


    @products.map do |product|
      product[:virtual_stock_store_1] = product.inventory(months).store_1.virtual
      product[:ideal_stock] = product.inventory(months).global.ideal
      product[:stock_deviation] = product.inventory(months).global.v_deviation
      product[:stock_deviation_percentile] = product.inventory(months).global.v_deviation_percentile

      product[:distributor] = product.distributors.first
      distributors.map do |distributor|
        if distributor.d_id == product[:distributor].d_id
          distributor[:ideal_stock] += product.inventory(months).global.ideal
          distributor[:stock_deviation] += product.inventory(months).global.deviation
          distributor[:ponderated_deviation] = (distributor[:stock_deviation] / distributor[:ideal_stock]) * 100
        end
      end
    end
    @products.map do |product|
      product[:distributor] = distributors.find { |distributor| distributor.d_id == product[:distributor].d_id}
    end

    @products.sort_by! { |product| [ product[:distributor][:ponderated_deviation], product.inventory(months).global.v_deviation_percentile, product.inventory(months).global.v_deviation ] }
    slim :reports_products_to_buy, layout: :layout_backend, locals: {title: R18n.t.reports_products_to_buy(months), sec_nav: :nav_administration, months: months}
  end


  route :get, :post, '/administration/reports/materials_to_buy' do
    months = params[:months].to_i unless params[:months].nil? || params[:months] == 0
    months ||= settings.desired_months_worth_of_bulk_in_warehouse
    reports_materials_to_buy months
  end
  def reports_materials_to_buy months
    @materials = Material.new.get_list([Location::W1, Location::W2]).all
    @materials.map do |material|
      material.update_stocks
      material.recalculate_ideals months
      material[:distributors] = material.distributors.all
    end
    @materials.sort_by! { |material| [ material[:stock_deviation_percentile], material[:stock_deviation] ] }
    @materials.delete_if { |material| material[:stock_deviation_percentile] >= settings.reports_percentage_threshold}
    slim :reports_materials_to_buy, layout: :layout_backend, locals: {title: R18n.t.reports_materials_to_buy(months), sec_nav: :nav_administration, months: months}
  end


  route :get, :post, '/production/reports/products_to_move' do
    months = params[:months].to_i unless params[:months].nil? || params[:months] == 0
    months ||= settings.desired_months_worth_of_items_in_store
    reports_products_to_move months
  end
  def reports_products_to_move months
    list = Product.new.get_all_but_archived.order(:categories__c_name, :products__p_name)
    products = Product.new.get_saleable_at_all_locations(list)
    @products = []
    products.map do |product|
      product[:stock_deviation] = product.inventory(months).store_1.v_deviation
      product[:stock_deviation_percentile] = product.inventory(months).store_1.v_deviation_percentile
      product[:ideal_stock] = product.inventory(months).store_1.ideal
      product[:to_move] = BigDecimal.new(0)
      product[:to_move] = product.inventory(months).store_1.v_deviation * -1 unless product.inventory(months).store_1.virtual >= product.inventory(months).store_1.ideal
      stock_in_current_location = eval("product.inventory(months).#{current_location[:name].downcase}.stock")
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
    slim :reports_products_to_move, layout: :layout_backend, locals: {title: R18n.t.reports_products_to_move(months, current_location[:translation]), sec_nav: :nav_production, months: months}
  end

end
