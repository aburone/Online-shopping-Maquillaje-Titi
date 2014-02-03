class Backend < AppController
  get '/logistics/?' do
    @orders = Order.new.get_packaging_orders.order(:o_id).reverse
    slim :logistics, layout: :layout_backend, locals: {sec_nav: :nav_logistics}
  end
end
