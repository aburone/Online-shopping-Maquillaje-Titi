Given /^I try to login into (.+) with user (.+) and location (.+)$/ do |page_name, username, location|
  visit path_to(page_name)
  within("#login_form") do
    fill_in 'admin_username', with: username
    fill_in 'admin_password', with: 'qwe123'
    choose (location)
    page.should have_selector(:link_or_button, 'Ingresar')
    click_button 'Ingresar'
  end
end

Then /^I should be rejected$/ do
   page.should have_content "Usuario, password o localizacion incorrectos."

end


# AfterStep('@wip') do
#   print "Press Return to continue"
#   STDIN.getc
# end
