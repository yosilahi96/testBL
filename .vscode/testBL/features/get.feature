@get_feature
Feature: Get Cypress

    @positive_case
    Scenario: user able to get
        When user send a "GET" request to "posts"
        Then the response code should be "200"
        Then the JSON response should follow schema "success_get.json"
        And the JSON response for get json should be return correctly