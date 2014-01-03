class Backend < AppController

  route :get, :post, '/inventory/reports/markups' do
    @products = Product.new.get_list
    slim :products_list, layout: :layout_backend, locals: {title: "Reporte de markups", sec_nav: :nav_logistics,
      can_edit: true, edit_link: :edit_product,
      full_row: true,
      price_pro_col: false,
      stock_col: false,
      markup_deviation_col: true
    }
  end
end
