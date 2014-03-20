When(/^I go to returns$/) do
  visit "/sales/returns"
  page.status_code.should == 200
  page.should have_content( t.returns.title )
end

When(/^It ask for a order code$/) do
  page.should have_content( t.returns.verify_order_code_legend )
end

When(/^I give it a valid code$/) do
  @order = get_a_sale_order
  fill_in( "o_code", with: @order.o_code)
  click_button( t.actions.verify )
  page.status_code.should == 200
  page.should have_content( t.order.details ConstantsTranslator.new(@order.type).t, @order.o_id, @order.o_code_with_dash )
end

When(/^The order is a sale$/) do
  @order.type.should == Order::SALE
end

When(/^The order is finished$/) do
  @order.o_status.should == Order::FINISHED
end

Then(/^It should ask for the items to be returned$/) do
  pending # express the regexp above with the code you wish you had
end

def get_a_sale_order
  rnd = rand( Order.filter(type: Order::SALE, o_status: Order::FINISHED).count(:o_id) )
  Order.where(type: Order::SALE, o_status: Order::FINISHED).limit(10, rnd).all.sample(1)[0]
end
