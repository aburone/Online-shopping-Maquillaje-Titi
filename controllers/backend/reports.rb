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
      multi_stock_col: true,
      persistent_headers: true

    }
  end

  get '/reports/stocks' do
    list = Product.new.get_list.where(tercerized: false)
    @products = Product.new.get_saleable_at_all_locations list
    slim :products_list, layout: :layout_backend, locals: {title: "Reporte de existencias", sec_nav: :nav_production,
      can_edit: true, edit_link: :edit_product,
      full_row: true,
      price_pro_col: false,
      stock_col: false,
      multi_stock_col: true,
      persistent_headers: true
    }
  end

end
