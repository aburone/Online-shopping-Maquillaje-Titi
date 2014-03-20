When(/^I go to returns$/) do
  visit "/sales/returns"
  page.status_code.should == 200
  page.should have_content( t.returns.title )
end

When(/^It ask for a order code$/) do
  page.should have_content( t.returns.verify_order_code_legend )
end

When(/^I give it a valid code$/) do
  fill_in( "o_code", with: "qwe123")
  click_button( t.actions.verify )
  page.status_code.should == 200
  pending # express the regexp above with the code you wish you had
end

When(/^The order is a sale$/) do
  pending # express the regexp above with the code you wish you had
end

When(/^The order is a closed$/) do
  pending # express the regexp above with the code you wish you had
end

Then(/^It should ask for the items to be returned$/) do
  pending # express the regexp above with the code you wish you had
end
