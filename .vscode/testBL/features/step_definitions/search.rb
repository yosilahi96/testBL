require 'selenium-webdriver'

Given /^that I have gone to the Bukalapak page$/ do
  @browser = Selenium::WebDriver.for :firefox
  @browser.navigate.to 'https://bukalapak.com/'
end

When /^I add kulkas to the search box$/ do
  @browser.find_element(:name, 'search[keywords]').send_keys 'kulkas'
end

And /^click the Search Button$/ do
  @browser.find_element(:class, 'v-omnisearch__submit').click
end

Then /^"(.*)" should be mentioned in the results$/ do |item|
  @browser.title.should include(item)
end