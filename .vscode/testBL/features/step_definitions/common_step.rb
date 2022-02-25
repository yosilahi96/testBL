Given(/^user set request header$/) do
  @headers = {
    'Accept': 'application/json',
    'Content-Type': 'application/json',
    'Authorization': @credentials
  }
end

Given(/^user using "(.*)" credentials$/) do |credential_type|
  @credentials = DataHelper.new('user').prepare_credentials(credential_type)
  step 'user set request header'
end

When(/^user get request body template from "(.*?).(yml|json)"$/) do |filename, extension|
  path_body = "#{Dir.pwd}/features/body/#{filename}.#{extension}"

  raise %(File not found: '#{path_body}') unless File.file? path_body

  case extension
  when 'yml'
    @body = YAML.safe_load File.open(path_body)
  when 'json'
    @body = JSON.parse File.read(path_body)
  else
    raise %(Unsupported file type: '#{path_body}')
  end
end

When(/^user send a "(.*)" request to "(.*)" with:$/) do |method, url, params|
  url = "#{ENV['BASE_URL']}/#{url}"
  unless params.hashes.empty?
    query = params.hashes.first.map do |key, value|
      value[0] == '@' ? %(#{key}=#{instance_variable_get(value)}) : %(#{key}=#{value})
    end.join('&')
    request_url = url.include?('?') ? %(#{url}&#{query}) : %(#{url}?#{query})
  end

  @headers = {} if @headers.nil?

  step 'user convert request body as JSON' if @headers[:'Content-type'].eql? 'application/json'

  retries ||= 0
  begin
    begin
      response = case method
                 when 'GET'
                   RestClient::Request.execute(method: :get, url: request_url, headers: @headers, payload: @body,
                                               timeout: 120, open_timeout: 120)
                 when 'POST'
                   RestClient.post request_url, @body, @headers
                 when 'PATCH'
                   RestClient.patch request_url, @body, @headers
                 when 'PUT'
                   RestClient.put request_url, @body, @headers
                 else
                   RestClient.delete request_url, @headers
                 end
    rescue RestClient::Exception => e
      response = e.response
    end

    expect(response.nil?).to eq false
  rescue Exception => e
    p e.message
    retry if (retries += 1) < 5
    raise e.message if retries == 5
  end

  @response = CucumberApi::Response.create response
  @headers = nil
  @body = nil
  $cache[request_url.to_s] = @response if method.to_s == 'GET'
end

When(/^user send a "(.*)" request to "(.*)"$/) do |method, path|
  url = URI("#{ENV['BASE_URL']}/#{path}")
  request_url = url.to_s
  if (method == 'GET') && $cache.key?(request_url.to_s)
    @response = $cache[request_url.to_s]
    @headers = nil
    @body = nil
    next
  end
  puts request_url
  puts "body #{@body}"
  @headers = {} if @headers.nil?
  retries = 0
  begin
    begin
      response =  case method
                  when 'GET'
                    RestClient::Request.execute(method: :get, url: request_url, headers: @headers, payload: @body,
                                                timeout: 120, open_timeout: 120)
                  when 'POST'
                    RestClient.post request_url, @body, @headers
                  when 'PATCH'
                    RestClient.patch request_url, @body, @headers
                  when 'PUT'
                    RestClient.put request_url, @body, @headers
                  else
                    RestClient.delete request_url, @headers
                  end
    rescue RestClient::Exception => e
      response = e.response
    end
    @response = CucumberApi::Response.create response
    expect(response.nil?).to eq false
  rescue Exception => e
    raise e.message if (retries += 1) == 5

    p e.message
    retry
  end

  puts "response body #{@response}"
  @headers = nil
  @body = nil
  $cache[request_url.to_s] = @response if method.to_s == 'GET'
end

Then(/^the response code should be "(.*)"$/) do |status_code|
  puts "response body #{@response.body}"
  expect(@response.code).to eq status_code.to_i
end

# we can use instance variable '@' to compare the value beside direct input
Then(/^the JSON response should have "(.*)" with type "(.*)" and value "(.*)" "(.*)"$/) do |json_path, type, comparison_type, value|
  if value.include? '@'
    # get value from instance variable
    value = instance_variable_get(value.to_s)
  elsif value.include? 'txt'
    # get value from localization
    value = I18n.t(value.to_s)
  end
  puts "value: #{value}"
  expect(@response.get_as_type_and_check_value(json_path, type, comparison_type, resolve(value))).to eq true
end

# checking response body for multipart/form-data using Net::HTTP
Then(/^the JSON response should have "(.*)" with type "(.*)" and value "(.*)" "(.*)" using NET$/) do |json_path, data_type, comparison_type, value|
  value = value.to_i if data_type.eql? 'numeric'
  case comparison_type
  when 'equal'
    expect(JSON.parse(@response.body)[json_path]).to eq value
  when 'not equal'
    expect(JSON.parse(@response.body)[json_path]).not_to eq value
  when 'include'
    expect(JSON.parse(@response.body)[json_path]).to include(value)
  end
end

# checking response body for multipart/form-data using Net::HTTP
Then(/^the response code should be "(.*)" using NET$/) do |status_code|
  expect(@response.code).to eq status_code
end

Then(/^the JSON array response should have "(.*)" with type "(.*)" from array "(.*)" index "(.*)" and value "(.*)" "(.*)"$/) do |key, type, array_path, index, comparison_type, value|
  value = instance_variable_get(value.to_s) if value.include? '@'

  index = case index
          when 'first'
            0
          when 'latest'
            @response.get(array_path).size - 1
          when 'the last 2'
            @response.get(array_path).size - 2
          else
            index
          end
  json_path = "#{array_path}[#{index}].#{key}"
  @response.get_as_type_and_check_value json_path, type, comparison_type, value
end

# Purpose : find the response value using key path and store it to instance variable
# ex : { "effective_date": "", "ReimbursementRequestBenefit": [{"amount": "20", "reimbursement_benefit_id_fk":1980}],"flagRequestReimbursementMyInfo": "1"}
# user grab "$..ReimbursementRequestBenefit[0].amount" value from response as instance variable "amount"
# The response store to instance variable as @amount
When(/^user grab "([^"]+)" value from response as instance variable "([^"]+)"$/) do |k, v|
  raise 'No response found.' if @response.nil?

  k = "$.#{k}" unless k[0] == '$'
  instance_variable_set("@#{v}", @response.get(k))
end

When(/^user set current date as instance variable$/) do
  date = Time.now
  instance_variable_set('@month', date.month)
  instance_variable_set('@year', date.year)
  instance_variable_set('@date', date.strftime('%Y-%m-%d'))
  instance_variable_set('@current_month_v1', date.strftime('%m/%Y'))
  instance_variable_set('@current_month_v2', date.strftime('%Y-%m'))
  instance_variable_set('@current_time', date.strftime('%Y-%m-%d %H:%M'))
end

When(/^user set value "(.*)" as instance variable "(.*)"$/) do |value, key|
  instance_variable_set("@#{key}", value)
end

Then(/^the JSON response should follow schema "(.*?).(yml|json)"$/) do |schema, extension|
  file_path = "#{Dir.pwd}/features/schemas/#{schema}.#{extension}"
  if File.file? file_path
    begin
      JSON::Validator.validate!(file_path, @response.to_s)
    rescue JSON::Schema::ValidationError
      raise JSON::Schema::ValidationError.new(%(#{$ERROR_INFO.message}\n#{@response.to_json_s}),
                                              $ERROR_INFO.fragments, $ERROR_INFO.failed_attribute, $ERROR_INFO.schema)
    end
  else
    puts %(WARNING: missing schema '#{file_path}')
    pending
  end
end

Then(/^the JSON response should not have "(.*)"$/) do |key|
  expect(@response.get(key)).to eq nil
end

Then(/^the body response should include text "(.*)"$/) do |text|
  @response.response_include_text(text, @response)
end

When(/^JSON response have "(.*)" array with collection type "(.*)" and value "(.*)" "(.*)"$/) do |json_path, type, comparison_type, value|
  puts "response body #{@response.body}"
  value = instance_variable_get(value.to_s) if value.include? '@'
  json = JSON.parse @response.body
  results = JsonPath.new(json_path).on(json)

  # the expected data should not be empty
  raise %(Expected data is an empty array) if results.empty?

  case type
  when 'numeric'
    expect(results.all? { |x| x.is_a? Numeric }).to eq true if comparison_type.eql? 'all'
    expect(results.any? { |x| x.is_a? Numeric }).to eq true if comparison_type.eql? 'any'
  when 'array'
    expect(results.all? { |x| x.is_a? Array }).to eq true if comparison_type.eql? 'all'
    expect(results.any? { |x| x.is_a? Array }).to eq true if comparison_type.eql? 'any'
  when 'string'
    expect(results.all? { |x| x.is_a? String }).to eq true if comparison_type.eql? 'all'
    expect(results.any? { |x| x.is_a? String }).to eq true if comparison_type.eql? 'any'
  when 'boolean'
    expect(results.all? { |x| [true, false].include? x }).to eq true if comparison_type.eql? 'all'
    expect(results.any? { |x| [true, false].include? x }).to eq true if comparison_type.eql? 'any'
  when 'numeric_string'
    expect(results.all? { |x| (x.is_a? Numeric) || x.is_a?(String) }).to eq true if comparison_type.eql? 'all'
    expect(results.any? { |x| (x.is_a? Numeric) || x.is_a?(String) }).to eq true if comparison_type.eql? 'any'
  when 'object'
    expect(results.all? { |x| x.is_a? Hash }).to eq true if comparison_type.eql? 'all'
    expect(results.any? { |x| x.is_a? Hash }).to eq true if comparison_type.eql? 'any'
  end

  case comparison_type
  when 'all'
    expect(results.all? { |x| x.eql? value }).to eq true
  when 'any'
    expect(results.any? { |x| x.eql? value }).to eq true
  when 'not any'
    expect(results.any? { |x| x.eql? value }).to eq false
  end
  @array_result = results
end

When(/^JSON response have "(.*)" array "(.*)" to be "(.*)"$/) do |json_path, type, value|
  puts "response body #{@response.body}"
  json = JSON.parse @response.body
  results = JsonPath.new(json_path).on(json)
  value = instance_variable_get(value.to_s) if value.include? '@'

  case type
  when 'size', 'page'
    expect(results.size).to be <= value.to_i
  when 'sort', 'order'
    expect(results).to eq results.sort(&:casecmp) if value.include?('asc')
    expect(results).to eq results.sort(&:casecmp).reverse if value.include?('desc')
  when 'search'
    expect(results[0]).to eq value
  end
end

When(/^user attach image attachment using "(.*)" image$/) do |filename|
  filename = 'image.png' if filename.eql? 'default'
  file = "./features/data/image/#{filename}"

  @body ||= {}
  @body['file'] = '' if filename.eql? 'blank_file'
  @body['file'] = File.open(file, 'r') unless filename.eql? 'blank_file'
end

Given(/^user add headers:$/) do |params|
  params.hashes.first.each do |key, value|
    @headers[key] = value[0] == '@' ? instance_variable_get(value) : value
  end
end

When(/^user clear the response "(.*)" cache$/) do |path|
  url = URI("#{ENV['BASE_URL']}/#{path}")
  request_url = url.to_s
  $cache.delete(request_url) if $cache.key?(request_url)
end

When(/^user convert request body as JSON$/) do
  @body = @body.to_json
end
