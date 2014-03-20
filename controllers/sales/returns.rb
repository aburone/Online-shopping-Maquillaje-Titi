class Sales < AppController

  route :get, :post, '/returns' do
    ap params
    @order = Order.new
    slim :returns, layout: :layout_sales, locals: {sec_nav: false}
  end

end
