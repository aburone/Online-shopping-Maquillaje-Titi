class Backend < AppController

  route :get, :post, '/administration/adjustments/mass_price_adjustments' do
    params[:mod] = params[:mod].to_s.gsub(',', '.') unless params[:mod].nil?
    mod =  BigDecimal.new(params[:mod], 2) unless params[:mod].nil? or params[:mod].to_f <= 0
    if !params[:mod].nil? && params[:mod].empty?
      flash[:warning] = "Tenes que decirme por cuanto multiplicar."
      redirect to("/administration/adjustments/mass_price_adjustments")
    elsif !params[:mod].nil? && params[:mod] == "0"
      flash[:warning] = "Multiplicar por cero no es una buena idea."
      redirect to("/administration/adjustments/mass_price_adjustments")
    elsif !params[:mod].nil? && params[:mod] <= "0"
      flash[:warning] = "Que estas intentando probar?."
      redirect to("/administration/adjustments/mass_price_adjustments")
    elsif !params[:mod].nil? && mod.nil?
      flash[:warning] = "Anda a jugar al medio de la autopista."
      redirect to("/administration/adjustments/mass_price_adjustments")
    else
      @products = mass_price_adjustments(mod, params['attribute'], params[:confirm] == R18n.t.inventory.mass_price_adjustments.submit_text) if mod
      flash.now[:notice] = "Precios actualizados con un indice de #{mod.to_f}" if params[:confirm] == R18n.t.inventory.mass_price_adjustments.submit_text and mod
      slim :mass_price_adjustments, layout: :layout_backend, locals: {sec_nav: :nav_administration, mod: mod}
    end
  end

  def mass_price_adjustments mod, attribute, save
    final_products = []
    threshold = Sequel.date_sub(Time.now.getlocal("-00:03").to_date.iso8601, {days: settings.price_updated_at_threshold})
    products = Product.new.get_all
                .where{Sequel.expr(:price_updated_at) < threshold}
                .all
    DB.transaction do
      if save
        message = "Actualizancion masiva de #{eval("t.product.fields.#{attribute}")} de productos. multiplicador: #{mod.to_f}"
        ActionsLog.new.set(msg: message, u_id: User.new.current_user_id, l_id: "GLOBAL", lvl: ActionsLog::NOTICE)
      end
      products.map do |product|
        product.price_mod(mod, save) if attribute == 'price'
        product.buy_cost_mod(mod, save) if attribute == 'buy_cost'
        product.save verify: false if save
        final_products << product
      end
      if save & attribute == 'price'
          message = "Actualizancion masiva de todos los items en proceso o listos para ser vendidos. Multiplicador: #{mod.to_f}"
          ActionsLog.new.set(msg: message, u_id: User.new.current_user_id, l_id: "GLOBAL", lvl: ActionsLog::NOTICE)
          DB.run "UPDATE items
          JOIN products using(p_id)
          SET items.i_price = products.price, items.i_price_pro = products.price_pro
          WHERE i_status IN ( 'ASSIGNED', 'MUST_VERIFY', 'VERIFIED', 'READY' )"
      end
    end
    final_products
  end


  route :get, :put, '/administration/adjustments/update_by_sku' do
    products = []
    missing_skus = []
    unless params[:raw_data].nil?
      sku_cols = []
      keys = {sku_on_a: 0, sku_on_b: 1, sku_on_c: 2}
      params.select { |key, value| sku_cols << keys[key.to_sym] if keys.has_key? key.to_sym }

      rows = params[:raw_data].to_s.split("\n").collect { |row| row.split("\t").collect{ |col| col.gsub(/\n|\r|\t/, '').squeeze(" ").strip} }
      rows.each do |row|
        sku = row.select.with_index{ |col, i| col if sku_cols.include? i }.reject(&:empty?).join('')
        sku = sku.to_s.gsub(/\n|\r|\t/, '').squeeze(" ").strip

        product = Product.new.get_by_sku sku
        missing_skus << sku if product.empty? unless sku.empty?
        unless product.empty?

          new_buy_cost = params[:buy_cost_on].empty? ? 0 : BigDecimal.new(Utils::as_number(row[params[:buy_cost_on].to_i]), 4)
          product[:new_buy_cost] = new_buy_cost > 0 ? new_buy_cost : product.buy_cost

          new_ideal_markup = params[:ideal_markup_on].empty? ? 0 : BigDecimal.new(Utils::as_number(row[params[:ideal_markup_on].to_i]), 4)
          product[:new_ideal_markup] = new_ideal_markup > 0 ? new_ideal_markup : product.ideal_markup

          new_price = params[:price_on].empty? ? 0 : BigDecimal.new(Utils::as_number(row[params[:price_on].to_i]), 4)
          product[:new_price] = new_price > 0 ? new_price : product.price

          products << product
          if params[:confirm]
            p = product.dup
            p.buy_cost = product[:new_buy_cost]
            p.ideal_markup = product[:new_ideal_markup]
            p.price = product[:new_price]
            p.recalculate_markups
            p.save
          end
        end
      end
      flash.now['error'] = {"#{t.products.update_by_sku.errors_found missing_skus.size}".to_sym => missing_skus} unless missing_skus.empty?
    end
    slim :update_by_sku, layout: :layout_backend, locals: {products: products, missing_skus: missing_skus}
  end
end