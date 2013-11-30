When /^I fill with a printed label$/ do
  label = Label.new.get_printed.first
  fill_in 'ajax_label_selector', with: "#{label.i_id}\n"
  unless ENV['IN_BROWSER']
    fill_in 'ajax_selected_label', with: "#{label.i_id}\n"
  end
  fill_in 'product_selector', with: 2
end

When /^I select a packaging order for verification$/ do
  all('.item').last.first(:link).click
end

When /^I verify all items$/ do 
  @o_id = current_path.scan(/\d+/).last.to_i
  items = Item
            .filter(i_status: Item::MUST_VERIFY)
            .join(:line_items, [:i_id], o_id: @o_id)
            .all

  items.each {|item| item.change_status Item::VERIFIED, @o_id }
end

When /^I select a packaging order for allocation$/ do
  all('.item').last.first(:link).click
end

Then /^I should see the correct title for the allocation of a packaging order$/ do
  title = "Imputando la orden Nº #{@o_id} al inventario"
  page.should have_content(title)
end

Then /^The allocation must take place$/ do
  click_button("Imputar orden a Deposito 2")
  unless ENV['IN_BROWSER']
    click_button("Imputar orden a Deposito 2")
  end
  page.should have_content("Orden Nº #{@o_id} procesada e imputada al inventario" )
end

