@create_feature
Feature: Create Cypress

@positive_case
Scenario: user able to create
And user get request body template from "create.json"
When user send a "POST" request to "posts"
Then the response code should be "201"
Then the JSON response should follow schema "success_create.json"
Then the JSON response for create json should be return correctly

