And(/^the JSON response for get json should be return correctly$/) do
    step 'the JSON response should have "$..userId" with type "numeric" and value "equal" "1"'
    step 'the JSON response should have "$..id" with type "numeric" and value "equal" "1"'
    step 'the JSON response should have "$..title" with type "string" and value "equal" "sunt aut facere repellat provident occaecati excepturi optio reprehenderit"'
  end
  