When(/^I type "(.*?)" in admin_username$/) do |arg1|
  fill_in 'admin_username', with: 'aburone'
end

When(/^I type "(.*?)" in password$/) do |arg1|
  fill_in 'admin_password', with: 'qwe123'
end

When(/^I click "(.*?)"$/) do |arg1|
  click_button arg1
end

