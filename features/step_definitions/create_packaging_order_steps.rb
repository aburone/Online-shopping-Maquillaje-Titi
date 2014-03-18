When /^I fill with a printed label$/ do
  label = Label.new.get_printed.first
  page.should have_content( "Seleccionar el producto" ) #t.production.select_product
  all('.item').sample.click
  page.should have_content("Lee la etiqueta del proximo")
  fill_in 'i_id', with: "#{label.i_id}"
  click_button("Aceptar")
  page.should have_content("Si es correcto")
  click_button("Aceptar")
  with_scope('.flash') { page.should have_content("asignada al producto") }
  page.should have_content( "Lee la etiqueta del proximo" )
  click_link( "Seleccionar un producto distinto" ) #t.order_select_other_product:
end

When /^I select a packaging order for verification$/ do
  all('.item').last.first(:link).click
end

When /^I remove one item I should see one less$/ do
  @o_id = get_o_id
  @count = all('.item').count
  if @count > 0
    id = all('.item').first.first('td').text
    click_link( "Remover un item de la orden" )
    fill_in 'id', with: id
    click_button("Aceptar")
    with_scope('.flash') { page.should have_content("Etiqueta dissociada del producto y la orden") }
    all('.item').count.should == @count - 1
    @count = @count - 1
  end
end

When /^I select a packaging order for allocation$/ do
  @o_id = get_o_id
  all('.item').last.first(:link).click
end

Then /^I should see the correct title for the allocation of a packaging order$/ do
  page.should have_content( t.production.allocation.title get_o_id )
end

Then /^If there are missing materials, I should add them$/ do
  if page.has_table?('missing_materials')
    missing_materials = page.find('#missing_materials')
    items = missing_materials.all('.item')
    puts "There are #{items.count} missing materials in order #{@o_id}"

    start = current_path
    items.each do |item|
      puts "Adding 999 units"
      first("table#missing_materials a.edit[href]").click
      click_button( "Crear nuevo" )
      el = find('#ajax_bulks_list').first('a')
      visit(el['href'])
      fill_in 'b_qty', with: "999"
      select 'IN_USE', from: "b_status"
      click_button( t.actions.apply )
      visit start
    end
  else
    puts "there are NO missing materials in order #{@o_id}"
  end
end

Then /^The allocation must take place$/ do
  click_button( t.production.allocation.allocate "Deposito 2")
  page.should have_content( t.production.allocation.ok @o_id )
end


def get_o_id
  @o_id = current_path.scan(/\d+/).last.to_i
  @o_id
end
