When(/^I go to warehouse_arrivals$/) do
  visit "/admin/transport/arrivals/select"
  page.status_code.should == 200
  page.should have_content( t.transport.arrivals.title )
end

When(/^I go to departure_pos_to_wh$/) do
  visit "/sales/transport/departures/pos_to_wh/select"
  page.status_code.should == 200
  page.should have_content( t.transport.departures.pos_to_wh.title )
end

When(/^I go to departure_wh_to_pos$/) do
  visit "/admin/transport/departures/wh_to_pos/select"
  page.status_code.should == 200
  page.should have_content( t.transport.departures.wh_to_pos.title )
end

When(/^I go to departure_wh_to_wh$/) do
  visit "/admin/transport/departures/wh_to_wh/select"
  page.status_code.should == 200
  page.should have_content( t.transport.departures.wh_to_wh.title )
end

When(/^I go to store_arrivals$/) do
  visit "/sales/transport/arrivals/select"
  page.status_code.should == 200
  page.should have_content( t.transport.arrivals.title )
end


When /^I fill with some items from s1$/ do
  init_r18

  count = all('.item').count
  i_id = add_and_remove_item Location::S1
  all('.item').count.should == count
  count = all('.item').count
  p "Adding new item #{count + 1}"
  add i_id

  all('.item').count.should == count + 1
  count = all('.item').count
  p "Removing item #{count - 1}"
  remove_item i_id
  all('.item').count.should == count -1

  count = all('.item').count
  add_invalid
  all('.item').count.should == count

  count = all('.item').count
  i_id = add_ready_item Location::S1
  all('.item').count.should == count + 1

  p "Adding same item again #{all('.item').count}"
  count = all('.item').count
  add i_id
  all('.item').count.should == count

  count = all('.item').count
  p "Adding new item #{count + 1}"
  i_id = add_ready_item Location::S1
  all('.item').count.should == count + 1

  puts "Order: #{get_o_id_from_current_path}"
end



When /^I fill with some items from w1$/ do
  init_r18

  count = all('.item').count
  p "Initial count: #{count}"
  i_id = add_and_remove_item Location::W1
  all('.item').count.should == count
  add i_id

  all('.item').count.should == count + 1
  count = all('.item').count
  remove_item i_id
  all('.item').count.should == count -1

  count = all('.item').count
  add_invalid
  all('.item').count.should == count

  count = all('.item').count
  i_id = add_ready_item Location::W1
  all('.item').count.should == count + 1

  p "Adding same item again #{all('.item').count}"
  count = all('.item').count
  add i_id
  all('.item').count.should == count

  count = all('.item').count
  p "Adding new item #{count + 1}"
  i_id = add_ready_item Location::W1
  all('.item').count.should == count + 1
  count = all('.item').count
  p "Final count: #{count}"
end


When /^I fill with some items from w2$/ do
  init_r18

  count = all('.item').count
  p "Initial count: #{count}"
  i_id = add_and_remove_item Location::W2
  all('.item').count.should == count
  add i_id

  all('.item').count.should == count + 1
  count = all('.item').count
  remove_item i_id
  all('.item').count.should == count -1

  count = all('.item').count
  add_invalid
  all('.item').count.should == count

  count = all('.item').count
  i_id = add_ready_item Location::W2
  all('.item').count.should == count + 1

  p "Adding same item again #{all('.item').count}"
  count = all('.item').count
  add i_id
  all('.item').count.should == count

  count = all('.item').count
  p "Adding new item #{count + 1}"
  i_id = add_ready_item Location::W2
  all('.item').count.should == count + 1
  count = all('.item').count
  p "Final count: #{count}"
end


When /^I fill with some bulks from w2$/ do
  init_r18

  count = all('.item').count
  b_id = add_and_remove_bulk Location::W2
  all('.item').count.should == count

  add b_id
  all('.item').count.should == count + 1

  count = all('.item').count
  remove_bulk b_id
  all('.item').count.should == count -1

  count = all('.item').count
  add_invalid
  all('.item').count.should == count

  count = all('.item').count
  b_id = add_ready_bulk Location::W2
  all('.item').count.should == count + 1

  p "Adding same bulk again #{all('.item').count}"
  count = all('.item').count
  add b_id
  all('.item').count.should == count

  count = all('.item').count
  p "Adding new bulk #{count + 1}"
  b_id = add_ready_bulk Location::W2
  all('.item').count.should == count + 1
end




def init_r18
  @r18 = R18n::I18n.new('es', './locales')
end

def add_and_remove_item location
  @count = all('.item').count
  item = Item.filter(i_status: Item::READY, i_loc: location).first
  add item.i_id
  click_button( @r18.t.actions.undo )
  all('.item').count.should == @count
  item.i_id
end

def add_and_remove_bulk location
  @count = all('.item').count
  bulk = Bulk.filter(b_status: [Bulk::NEW, Bulk::IN_USE], b_loc: location).first
  add bulk.b_id
  click_button( @r18.t.actions.undo )
  all('.item').count.should == @count
  bulk.b_id
end

def remove_item id
  count = all('.item').count
  p "Removing one item of #{count}"
  click_link( "Remover un item de la orden" )
  add2 id
  all('.item').count.should == count - 1
end

def remove_bulk id
  count = all('.item').count
  p "Removing one bulk of #{count}"
  click_link( "Remover un granel de la orden" )
  add2 id
  all('.item').count.should == count - 1
end

def add_ready_item location
  count = all('.item').count
  item = Item.filter(i_status: Item::READY, i_loc: location).first
  add item.i_id
  all('.item').count.should == count + 1
  item.i_id
end

def add_ready_bulk location
  count = all('.item').count
  bulk = Bulk.filter(b_status: [Bulk::NEW, Bulk::IN_USE], b_loc: location).first
  add bulk.b_id
  all('.item').count.should == count + 1
  bulk.b_id
end


def add id
  fill_in 'i_id', with: id
  click_button( @r18.t.actions.ok )
  id
end

def add2 id
  fill_in 'id', with: id
  click_button( @r18.t.actions.ok )
  id
end

def add_invalid
  @count = all('.item').count
  add "hola"
  with_scope('.flash') { page.should have_content( @r18.t.errors.invalid_label ) }
  all('.item').count.should == @count
end

