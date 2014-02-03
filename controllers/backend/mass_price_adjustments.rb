class Backend < AppController
  def update_prices mod, save

    final_products = []
    products = Product.new.get_list
                .select(:p_id)
                .order(:c_name, :p_name)
    products = Sinatra::Base.development? ? products.limit(10) : products.all

    if save
      message = "Actualizancion masiva de precios de productos. multiplicador: #{mod.to_f}"
      ActionsLog.new.set(msg: message, u_id: User.new.current_user_id, l_id: "GLOBAL", lvl: ActionsLog::NOTICE).save
    end

    products.map do |pr|
      product = Product.new.get(pr.p_id)
      product.price_mod(mod, save)
      product.save verify: false, columns: Product::COLUMNS if save
      final_products << product
    end

    if save
        message = "Actualizancion masiva de todos los items en proceso o listos para ser vendidos. Multiplicador: #{mod.to_f}"
        ActionsLog.new.set(msg: message, u_id: User.new.current_user_id, l_id: "GLOBAL", lvl: ActionsLog::NOTICE).save
        DB.run "UPDATE items
        JOIN products using(p_id)
        SET items.i_price = products.price, items.i_price_pro = products.price_pro
        WHERE i_status IN ( 'ASSIGNED', 'MUST_VERIFY', 'VERIFIED', 'READY' )"
    end
    final_products
  end

  route :get, :post, '/inventory/adjustments/mass_price_adjustments' do
    params[:mod] = params[:mod].to_s.gsub(',', '.') unless params[:mod].nil?
    @mod =  BigDecimal.new(params[:mod], 2) unless params[:mod].nil? or params[:mod].to_f <= 0
    if !params[:mod].nil? && params[:mod].empty?
      flash[:warning] = "Tenes que decirme por cuanto multiplicar."
      redirect to("/inventory/adjustments/mass_price_adjustments")
    elsif !params[:mod].nil? && params[:mod] == "0" 
      flash[:warning] = "Multiplicar por cero no es una buena idea."
      redirect to("/inventory/adjustments/mass_price_adjustments")
    elsif !params[:mod].nil? && params[:mod] <= "0" 
      flash[:warning] = "Que estas intentando probar?."
      redirect to("/inventory/adjustments/mass_price_adjustments")
    elsif !params[:mod].nil? && @mod.nil?
      flash[:warning] = "Anda a jugar al medio de la autopista."
      redirect to("/inventory/adjustments/mass_price_adjustments")
    else
      @products = update_prices(@mod, params[:confirm] == R18n.t.inventory.mass_price_adjustments.submit_text) if @mod
      flash.now[:notice] = "Precios actualizados con un indice de #{@mod.to_f}" if params[:confirm] == R18n.t.inventory.mass_price_adjustments.submit_text and @mod
      slim :mass_price_adjustments, layout: :layout_backend, locals: {sec_nav: :nav_logistics}
    end
  end
end