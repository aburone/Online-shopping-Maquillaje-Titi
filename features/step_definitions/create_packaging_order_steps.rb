When /^I fill with a printed label$/ do
  label = Label.new.get_printed.first
  fill_in 'ajax_label_selector', with: label.i_id
  fill_in 'ajax_selected_label', with: label.i_id
  fill_in 'product_selector', with: 2
end

When /^I select a packaging order for verification$/ do
  all('.item').last.first(:link).click
end

When /^I verify all items$/ do 
  o_id = current_path.scan(/\d+/).last.to_i
  items = Item
            .filter(i_status: Item::MUST_VERIFY)
            .join(:line_items, [:i_id], o_id: o_id)
            .all

  items.each {|item| item.change_status Item::VERIFIED, o_id }
end

When /^I select a packaging order for allocation$/ do
  all('.item').last.first(:link).click
end

Then /^I should see the correct title for the allocation of a packaging order$/ do
  o_id = current_path.scan(/\d+/).first.to_i
  title = R18n::t.production.packaging_order_allocation.title(o_id)
  page.should have_content(title)
end

And /^The allocation must take place$/ do
  o_id = current_path.scan(/\d+/).first.to_i
  p o_id
  name = R18n::t.production.packaging_order_allocation.allocate("Deposito 2")
  click_button( name )
  page.should have_content(R18n::t.production.packaging_order_allocation.ok(o_id) )
end

