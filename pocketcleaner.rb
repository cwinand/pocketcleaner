require "net/http"

class PocketAPI
	API_BASE_URL = "https://getpocket.com/v3"
  API_RETRIEVE_PATH = "/get"
  API_MODIFY_PATH = "/send"
  AUTHORIZATION_REQUEST_PATH = "/oauth/request"
  AUTHORIZATION_REDIRECT_URI = "https://github.com/cwinand/pocketcleaner"


	def initialize(consumer_key)
		@consumer_key = consumer_key
	end

	def get_access_token
    
    @auth_request_query_data = URI.encode_www_form(
      "consumer_key" => "#{@consumer_key}",
      "redirect_uri" => "#{AUTHORIZATION_REDIRECT_URI}"
    )
    @auth_request = Net::HTTP.Post.new(API_BASE_URL)
		@auth_response = @auth_request.post(AUTHORIZATION_REQUEST_PATH, @auth_request_query_data)
    @access_token = @res.body
	end

end

class EvernoteAPI

	def initialize(consumer_key)
		@consumer_key = consumer_key
	end

end

pocket = PocketAPI.new(ARGV[0])
pocket.get_access_token
