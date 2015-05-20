require "net/http"
require "net/https"
require "json"
require "launchy"
require "openssl"
require "pp"

class PocketAPI
  attr_reader(
      :consumer_key,
      :access_token
  )

  API_BASE_URL = "https://getpocket.com"
  API_RETRIEVE_PATH = "/v3/get"
  API_MODIFY_PATH = "/v3/send"
  AUTHORIZATION_REQUEST_TOKEN_PATH = "/v3/oauth/request"
  AUTHORIZATION_ACCESS_TOKEN_PATH = "/v3/oauth/authorize"
  AUTHORIZATION_APPROVAL_PATH = "/auth/authorize"
  AUTHORIZATION_REDIRECT_URI = "https://github.com/cwinand/pocketcleaner"


  def initialize(consumer_key)
    @consumer_key = consumer_key
    @api_uri = URI.parse(API_BASE_URL)
    @api_request_header = {
        "Content-Type" => "application/json; charset=UTF8",
        "X-Accept" => "application/json"
    }

    @https = Net::HTTP.new(@api_uri.host, @api_uri.port)
    @https.use_ssl = true
    @https.verify_mode = OpenSSL::SSL::VERIFY_NONE
    # TODO: This is not safe! Do not run over unsecured connection. Fix SSL verification before going to production

  end

  def make_api_request(url, data)
    req = Net::HTTP::Post.new(url, @api_request_header)
    req.body = data

    @https.request(req)
  end

  def get_request_token
    auth_request_data = {
      :consumer_key => @consumer_key,
      :redirect_uri => AUTHORIZATION_REDIRECT_URI
    }.to_json

    auth_response = make_api_request(AUTHORIZATION_REQUEST_TOKEN_PATH, auth_request_data)

    response_body = JSON.parse(auth_response.body)
    @request_token = response_body["code"]
  end

  def send_for_approval
    approval_request_url = "#{API_BASE_URL}#{AUTHORIZATION_APPROVAL_PATH}?request_token=#{@request_token}&redirect_uri=#{AUTHORIZATION_REDIRECT_URI}"
    Launchy.open approval_request_url
  end

  def convert_request_token
    get_request_token
    send_for_approval

    approved = false
    attempts = 0
    convert_request_data = {
        :consumer_key => @consumer_key,
        :code => @request_token
    }.to_json

    while !approved
      convert_response = make_api_request(AUTHORIZATION_ACCESS_TOKEN_PATH, convert_request_data)
      if convert_response.kind_of? Net::HTTPSuccess
        approved = true
        convert_response_body = JSON.parse(convert_response.body)
        @access_token = convert_response_body["access_token"]
      elsif convert_response["X-Error-Code"].to_i == 158 && attempts < 10
        attempts++
        sleep(3)
      else
        break
      end
    end
  end

  def retrieve_favorites
    request_data = {
        :consumer_key => @consumer_key,
        :access_token => @access_token,
        :favorite => 1
    }.to_json

    retrieve_resp = make_api_request(API_RETRIEVE_PATH, request_data)
    retrieve_resp_body = JSON.parse(retrieve_resp.body)

    retrieve_resp_body["list"]
  end


end

class EvernoteAPI

  def initialize(consumer_key)
    @consumer_key = consumer_key
  end

end

pocket = PocketAPI.new(ARGV[0])

pocket.convert_request_token
pp pocket.retrieve_favorites
