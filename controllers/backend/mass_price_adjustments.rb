class Backend < AppController
  def update_prices mod, save

    final_products = []
    products = Product.new.get_list
                .filter(archived: false)
                .filter(Sequel.negate(products__br_name: "Mila Marzi"))
                .select(:p_id)
                .order(:c_name, :p_name)
                .all
    products.map do |pr|
      product = Product.new.get(pr.p_id)
      product.price_mod(mod)
      product.save columns: Product::COLUMNS if save
      final_products << product
    end
    final_products
  end

  route :get, :post, '/inventory/mass_price_adjustments' do
    @mod =  BigDecimal.new(params[:mod], 2) unless params[:mod].nil? or params[:mod].to_f == 0 or params[:mod].to_f == 1
    @products = update_prices(@mod, params[:confirm] == R18n.t.inventory.mass_price_adjustments.submit_text) if @mod
    flash[:notice] = "Precios actualizados con un indice de #{@mod.to_f}" if params[:confirm] == R18n.t.inventory.mass_price_adjustments.submit_text and @mod
    slim :mass_price_adjustments, layout: :layout_backend, locals: {sec_nav: :nav_logistics}
  end
end