@return
Feature: As a salesman I should be able to return items buyed by a client

Background:
  Given I am logged-in into sales with location STORE_1

Scenario: Return some items

Given I go to returns
When It ask for a order code
And I give it a valid code
And The order is a sale
And The order is a closed
Then It should ask for the items to be returned


# Scenario: Fail to teturn some items

# Given I go to returns
# When It ask for a order code
# And I give it a invalid code
# Then I should see an error

# Given I go to returns
# When It ask for a order code
# And I give it a valid code
# But The order is not a sale
# Then I should see an error

