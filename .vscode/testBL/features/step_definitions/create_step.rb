And(/^the JSON response for create json should be return correctly$/) do
    step 'the JSON response should have "$..title" with type "string" and value "equal" "recommendation"'
    step 'the JSON response should have "$..body" with type "string" and value "equal" "motorcycle"'
    step 'the JSON response should have "$..userId" with type "string" and value "equal" "12"'
    step 'the JSON response should have "$..id" with type "numeric" and value "equal" "101"'
end
