# frozen_string_literal: true

require 'dotenv'
require 'byebug'
require 'data_magic'
require 'json'
require 'jsonpath'
require 'rest-client'
require 'json-schema'
require 'cucumber-api'
require 'active_support/all'
require 'faker'


require 'aruba/version'
require 'aruba/api'
require 'aruba/cucumber/hooks'
require 'aruba/cucumber/command'
require 'aruba/cucumber/environment'
require 'aruba/cucumber/file'
require 'aruba/cucumber/testing_frameworks'

require 'capybara/cucumber'
require 'capybara-screenshot/cucumber'
require 'capybara/rspec'
require 'selenium-webdriver'
require 'site_prism'
require 'rspec/expectations'
require 'rspec/retry'

require 'uri'
require 'net/http'

include RSpec::Matchers

Dotenv.load

browser = 'chrome'.to_sym
base_url = ENV['SSO_BASE_URL']
wait_time = 30
SHORT_TIMEOUT = 30
DEFAULT_TIMEOUT = 30
DataMagic.yml_directory = './features/config'
report_root = File.absolute_path('./report')

if ENV['REPORT_PATH'].nil?
  # clear report files
  # this is same purpose with rake:clear_report on rakefile but run locally
  puts '=====:: Delete report directory via env.rb'
  FileUtils.rm_rf(report_root, secure: true)
  FileUtils.mkdir_p report_root

  # init report files
  # this is same purpose with rake:init_report on rakefile but run locally
  ENV['REPORT_PATH'] ||= Faker::Number.number(digits: 8).to_s
  puts "=====:: about to create report #{ENV['REPORT_PATH']} via env.rb"
end

path = "#{report_root}/#{ENV['REPORT_PATH']}"
FileUtils.mkdir_p path

browser_options = Selenium::WebDriver::Chrome::Options.new
browser_profile = Selenium::WebDriver::Chrome::Profile.new

if ENV['BROWSER'].eql? 'chrome_headless'
  browser_options.headless!
  browser_options.add_argument('--no-sandbox')
  browser_options.add_argument('--disable-gpu')
  browser_options.add_argument('--disable-dev-shm-usage')
  browser_options.add_argument('--enable-features=NetworkService,NetworkServiceInProcess')
end

browser_options.add_preference('download.default_directory', File.absolute_path('./features/data/downloaded'))
browser_options.add_preference(:download, default_directory: File.absolute_path('./features/data/downloaded'))
browser_options.add_preference(:browser, set_download_behavior: { behavior: 'allow' })
browser_options.add_preference('plugins.always_open_pdf_externally', true)
browser_options.add_preference(:plugins, always_open_pdf_externally: true)
browser_options.add_preference('profile.geolocation.default_content_setting', 1)
browser_options.add_preference('profile.default_content_setting_values.geolocation', 1)

Capybara.register_driver :chrome do |app|
  browser_options.add_argument('--window-size=1440,877')
  browser_options.add_argument('--user-agent=selenium')
  # browser_options.add_argument('--start-maximized')

  client = Selenium::WebDriver::Remote::Http::Default.new
  client.open_timeout = wait_time
  client.read_timeout = wait_time

  Capybara::Selenium::Driver.new(
    app,
    browser: :chrome,
    options: browser_options,
    http_client: client,
    profile: browser_profile
  )
end

RSpec.configure do |config|
  # show retry status in spec process
  config.verbose_retry = true
  # Try twice (retry once)
  config.default_retry_count = 2
  # Only retry when Selenium raises Net::ReadTimeout
  config.exceptions_to_retry = [Net::ReadTimeout]
end

# rubocop:disable Lint/ShadowingOuterLocalVariable
Capybara::Screenshot.register_driver(browser) do |driver, path|
  driver.browser.save_screenshot path
end
# rubocop:enable Lint/ShadowingOuterLocalVariable

p "about to run on #{browser} to #{base_url}"
Capybara.default_driver = browser

Capybara::Screenshot.autosave_on_failure = true
Capybara::Screenshot.prune_strategy = { keep: 50 }
Capybara::Screenshot.append_timestamp = true
Capybara::Screenshot.webkit_options = {
  width: 1440,
  height: 877
}
Capybara.save_path = "#{path}/screenshots"
# SitePrism.log_level = :DEBUG

Faker::Config.locale = 'id'


