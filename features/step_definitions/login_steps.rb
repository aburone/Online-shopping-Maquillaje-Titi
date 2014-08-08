When /^I logout from backend$/ do
  logout(:aburone)
  visit path_to("backend_logout")
end

Given /^I am logged-in into (.+) with location (.+)$/ do |page_name, location|
  visit path_to(page_name)
  # puts body
  within("#login_form") do
    fill_in 'admin_username', with: 'aburone'
    fill_in 'admin_password', with: '1234'
    choose (location)
  page.should have_selector(:link_or_button, 'Ingresar')
    click_button "submit"
  end
end

When(/^I type "(.*?)" in admin_username$/) do |arg1|
  fill_in 'admin_username', with: 'aburone'
end

When(/^I type "(.*?)" in password$/) do |arg1|
  fill_in 'admin_password', with: '1234'
end

When(/^I click "(.*?)"$/) do |arg1|
  click_button arg1
end
