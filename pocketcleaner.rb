require "net/http"
require "net/https"
require "json"
require "pp"

class PocketAPI
  API_BASE_URL = "https://getpocket.com"
  API_RETRIEVE_PATH = "/v3/get"
  API_MODIFY_PATH = "/v3/send"
  AUTHORIZATION_REQUEST_PATH = "/v3/oauth/request"
  AUTHORIZATION_REDIRECT_URI = "https://github.com/cwinand/pocketcleaner"


  def initialize(consumer_key)
    @consumer_key = consumer_key
  end

  def get_access_token
    @auth_request_data = {
      :consumer_key => "#{@consumer_key}",
      :redirect_uri => "#{AUTHORIZATION_REDIRECT_URI}"
    }.to_json
    @auth_request_header = {
      "Content-Type" => "application/json; charset=UTF8",
      "X-Accept" => "application/json"
    }
    @api_uri = URI.parse(API_BASE_URL)

    @https = Net::HTTP.new(@api_uri.host, @api_uri.port)
    @https.use_ssl = true

    @auth_request = Net::HTTP::Post.new(AUTHORIZATION_REQUEST_PATH, @auth_request_header)
    @auth_request.body(@auth_request_data)

    @access_token = @https.request(@auth_request)
  end

end

class EvernoteAPI

  def initialize(consumer_key)
    @consumer_key = consumer_key
  end

end

pocket = PocketAPI.new(ARGV[0])
pp pocket
pp pocket.get_access_token
