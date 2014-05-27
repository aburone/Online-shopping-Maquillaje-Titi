
When /^I verify all items$/ do
  i_ids = []
  all('.item').each { |item| i_ids <<  item.first('td').text }
  i_ids.each do |i_id|
    fill_in 'i_id', with: "#{i_id}"
    click_button("Aceptar")
    with_scope('.flash') { page.should have_content("Verificado") }
    # page.should have_content( "Verificando ingreso de mercaderia" )
  end
end


When /^I logout from backend$/ do
  logout(:aburone)
  visit path_to("backend_logout")
end

Given /^I am logged-in into (.+) with location (.+)$/ do |page_name, location|
  visit path_to(page_name)
  # puts body
  within("#login_form") do
    fill_in 'admin_username', with: 'aburone'
    fill_in 'admin_password', with: 'qwe123'
    choose (location)
	page.should have_selector(:link_or_button, 'Ingresar')
    click_button "submit"
  end
end

Then /^Show me the page$/ do
  puts body
end

Then /^show me the session cookies$/ do
  ap Capybara.current_session.driver.request.cookies
end

Then /^within id (.+) I should see (\d+) (.+)$/ do |id, number, classs|
  with_scope(id) do
    page.should have_css("\##{classs}", count: number.to_i)
  end
end

Then /^I should see (\d+) (.+)$/ do |number, classs|
  page.should have_css(".#{classs}", count: number.to_i)
end



When /^I click on "([^\"]+)"$/ do |text|
  matcher = ['*', { :text => text }]
  element = page.find(:css, *matcher)
  while better_match = element.first(:css, *matcher)
    element = better_match
  end
  element.click
end

# Use this to fill in an entire form with data from a table. Example:
#   When I fill in the following:
#     | Account Number | 5002       |
#     | Expiry date    | 2009-11-01 |
#     | Note           | Nice guy   |
#     | Wants Email?   |            |
# TODO: Add support for checkbox, select or option based on naming conventions.
When /^(?:|I )fill in the following(?: within "([^\"]*)")?:$/ do |selector, fields|
  with_scope(selector) do
    fields.rows_hash.each do |name, value|
      step %{I fill in "#{name}" with "#{value}"}
    end
  end
end



When /^selectors test$/ do
  included_defs.each do |data_set_name|
    click_button "+"
    select_node = all(:css, '.input-many-item select').last # There may be more than one of these
    select_node.find(:xpath, XPath::HTML.option(data_set_name), :message => "cannot select option with text '#{data_set_name}'").select_option
  end
  # all is like find, but it returns an array of matching nodes, so I can use .last and always get the last one.
  page.should have_css("#table", :text => "[Name]")
  page.should have_css('h2', :text => 'stuff')
end


def click_link_or_button(locator)
  find(:link_or_button, locator).click
end
# alias_method :click_on, :click_link_or_button
