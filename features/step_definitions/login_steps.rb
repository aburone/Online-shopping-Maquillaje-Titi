class SimpleUser
  attr_reader :username, :password
  def initialize username, password
    @username = username
    @password = password
  end
end

class LogInPage
  include Capybara::DSL
  def username_field
    find("input[id='admin_username']")
  end
  def password_field
    find("input[id='admin_password']")
  end
  def log_in_button
    find("input[id='submit']")
  end
  def log_in_as(user, location)
    username_field.set user.username
    password_field.set user.password
    choose(location)
    log_in_button.click
  end
end

Given /^I am logged-in into (.+) with location (.+)$/ do |page_name, location|
  visit path_to(page_name)
  LogInPage.new.log_in_as( SimpleUser.new("aburone", "1234"), location)
  page.should have_content R18n.t.auth.loggedin.to_s
end

Given /^I try to login into (.+) with user (.+) and location (.+)$/ do |page_name, username, location|
  visit path_to(page_name)
  LogInPage.new.log_in_as( SimpleUser.new(username, "1234"), location)
end

Then /^I should be rejected$/ do
   page.should have_content R18n.t.auth.invalid.to_s
end

Then /^I should be logged-in$/ do
  page.should have_content R18n.t.auth.loggedin.to_s
end





