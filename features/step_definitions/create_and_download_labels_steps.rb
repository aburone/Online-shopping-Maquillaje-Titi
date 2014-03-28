When(/^I go to labels$/) do
  visit "/admin/production/labels"
  page.status_code.should == 200
  page.should have_content( t.labels.title )
end




Then /^Stock of ribbon and labels should be lower$/ do
  pending # check the stock
end
