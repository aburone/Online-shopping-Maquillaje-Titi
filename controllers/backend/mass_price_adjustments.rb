class Backend < AppController
  def update_prices mod
    p mod
    products = Product.new.get_list.limit(10).all
    products.map do |product|
      puts product.p_name
      puts Utils::number_format product.price, 5
      product.price *= mod
      puts Utils::number_format product.price, 5
      p Utils::number_format product.price.modulo(1), 2
      # .each { |p| puts Utils::number_format p, 2}
    end
  end

  route :get, :post, '/inventory/mass_price_adjustments' do
    mod =  BigDecimal.new(params[:mod], 2) unless params[:mod].nil? or params[:mod].to_f == 0 or params[:mod].to_f == 1
    update_prices(mod) if mod
    slim :mass_price_adjustments, layout: :layout_backend, locals: {sec_nav: :nav_logistics}
  end
end