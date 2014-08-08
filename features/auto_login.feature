@wip
Feature: Auto login

Scenario: Auto log in to backend
Given I am logged-in into backend with location WAREHOUSE_1
Then I should see "Sesión iniciada como aburone" within ".flash"
