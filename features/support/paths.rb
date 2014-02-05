# Taken from the cucumber-rails project.

module NavigationHelpers
  # Maps a name to a path. Used by the
  #
  #   When /^I go to (.+)$/ do |page_name|
  #
  # step definition in web_steps.rb
  #
  def path_to(page_name)
    case page_name

    when /the home\s?page/
      '/'
    when /backend/
      '/admin'
    when /materials/
      '/admin/materials'
    when /production/
      '/admin/production'
    when /labels/
      '/admin/production/labels'
    when /packaging_list/
      '/admin/production/packaging/select'
    when /verification_list/
      '/admin/production/verification/select'
    when /allocation_list/
      '/admin/production/allocation/select'

    when /departure_wh_to_wh/
      "/admin/transport/departures/wh_to_wh/select"
    when /departure_wh_to_pos/
      "/admin/transport/departures/wh_to_pos/select"
    when /departure_pos_to_wh/
      "/sales/transport/departures/pos_to_wh/select"
    when /warehouse_arrivals/
      "/admin/transport/arrivals/select"

      
    when /sales/
      '/ventas'
    when /store_arrivals/
      "/sales/transport/arrivals/select"



    # Add more mappings here.
    # Here is an example that pulls values out of the Regexp:
    #
    #   when /^(.*)'s profile page$/i
    #     user_profile_path(User.find_by_login($1))

    else
      raise "Can't find mapping from \"#{page_name}\" to a path.\n" +
        "Now, go and add a mapping in #{__FILE__}"
    end
  end
end

World(NavigationHelpers)
