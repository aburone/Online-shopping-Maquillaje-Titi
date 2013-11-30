@wip
Feature: check login level

Scenario: try to login to a level 2 location with level 1 credentials
  Given I try to login into backend with user cristina and location WAREHOUSE_2
  Then I should be rejected
