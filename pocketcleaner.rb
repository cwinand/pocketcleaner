require "oauth"
require "oauth/consumer"
require "evernote_oauth"
require "net/http"
require "json"
require "launchy"
require "openssl"

class PocketAPI
  attr_reader(
      :consumer_key,
      :access_token,
      :modify_settings
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
    @modify_settings = {
        :unfavorite => true,
        :archive => true
    }

    puts "Do you want to unfavorite items that have been moved? yes/no"
    @modify_settings[:unfavorite] = false if $stdin.gets.chomp == 'no'
    puts "Do you want to archive items that have been moved? yes/no"
    @modify_settings[:archive] = false if $stdin.gets.chomp == 'no'


    convert_request_token
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

  def retrieve(favorites=0)
    request_data = {
        :consumer_key => @consumer_key,
        :access_token => @access_token,
        :favorite => favorites,
        :detailType => "complete"
    }.to_json

    retrieve_resp = make_api_request(API_RETRIEVE_PATH, request_data)
    retrieve_resp_body = JSON.parse(retrieve_resp.body)

    retrieve_resp_body["list"]
  end

  def modify(id, is_individual=true)
    request_data = {
        :consumer_key => @consumer_key,
        :access_token => @access_token,
        :actions => []
    }

    if @modify_settings[:archive] || @modify_settings[:unfavorite]
      if @modify_settings[:archive]
        action = {
            :item_id => id,
            :action => 'archive'
        }
        request_data[:actions].push action
      end

      if @modify_settings[:unfavorite]
        action = {
            :item_id => id,
            :action => 'unfavorite'
        }
        request_data[:actions].push action
      end
    end

    #usually modify will be run in batch through the modify_list method
    #but we can send the modify request on an individual basis if needed
    if is_individual
      modify_resp = make_api_request(API_MODIFY_PATH, request_data.to_json)
      modify_resp_body = JSON.parse(modify_resp.body)
    else
      request_data[:actions]
    end
  end

  def modify_list(list)
    request_data = {
        :consumer_key => @consumer_key,
        :access_token => @access_token,
        :actions => []
    }

    list.each do |item|
      actions = modify(item[:id], false)
      actions.each do |action|
        request_data[:actions].push action
      end
    end

    modify_resp = make_api_request(API_MODIFY_PATH, request_data.to_json)
    modify_resp_body = JSON.parse(modify_resp.body)
  end

  def process_list(list)
    list = list
    modified_list = []

    if list.empty?
      puts "this list is empty"
    else
      list.each do |id, item|
        #don't need query string info from linked urls
        url = item['resolved_url'].split("?")[0]

        content = "<a href='#{URI.escape(url)}'>#{url}</a>"
        content += "<div><br /></div>"
        content += CGI.escapeHTML(item['excerpt'])

        title = if item["resolved_title"].empty?
                  url
                else
                  item["resolved_title"]
                end

        note_data = {
            :id => id,
            :title => title,
            :content => content
        }

        if item["tags"].count > 1
          puts "What tag do you want for the article \"#{title}\""
          puts "Available: #{item['tags'].keys}"
          selected = $stdin.gets.chomp

          while !item['tags'].include? selected
            puts "You typed '#{selected}' which is not in the list of tags."
            puts "Try again: #{item['tags'].keys}"
            selected = $stdin.gets.chomp
          end

          note_data[:notebook] = selected
        else
          note_data[:notebook] = item["tags"].keys[0]
        end

        modified_list.push(note_data)
        end
    end

    modified_list
  end

end

class EvernoteAPI
  attr_reader(
      :note_store,
      :developer_token,
      :pocket_tag_as_notebook
  )

  def initialize(developer_token, sandbox=false)
    @developer_token = developer_token

    # Set up the NoteStore client
    @client = EvernoteOAuth::Client.new(
        token: developer_token,
        sandbox: sandbox
    )

    begin
      @note_store = @client.note_store
    rescue Evernote::EDAM::Error::EDAMSystemException => raised_error
      puts "Authentication failed"
      puts "Error Code: #{raised_error.errorCode}"
      puts "Message: #{raised_error.message}"
    end

    @pocket_tag_as_notebook = {
        :business => "Business Reference",
        :career => "Career Reference",
        :christianity => "Bible/Christianity Reference",
        :design => "Design Reference",
        :dev => "Development Reference",
        :family => "Family/Home Reference",
        :food => "Cooking Reference",
        :health => "Health Reference",
        :workflow => "Work/Productivity Reference"
    }

  end

  def make_note(note_body="", note_title="", notebook=nil)
    note_body = note_body

    n_body = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>"
    n_body += "<!DOCTYPE en-note SYSTEM \"http://xml.evernote.com/pub/enml2.dtd\">"
    n_body += "<en-note>#{note_body}</en-note>"

    note = Evernote::EDAM::Type::Note.new
    note.title = note_title
    note.content = n_body
    note.notebookGuid = notebook
    note.tagNames = ["needs-tagged"]

    created_note = @note_store.createNote(note)
  end



  def make_all_notes(list)
    available_notebooks = @note_store.listNotebooks

    list.each_with_index do |note, index|
      print "Adding article #{index} of #{list.length - 1}: '#{note[:title]}'\r"
      $stdout.flush

      notebook_guid = nil
      notebook_name_from_note = @pocket_tag_as_notebook[note[:notebook].to_sym]

      available_notebooks.each do |notebook|
        notebook_guid = notebook.guid if notebook.name === notebook_name_from_note
      end

      note[:notebook] = notebook_guid

      begin
        make_note(note[:content], note[:title], note[:notebook])
      rescue Evernote::EDAM::Error::EDAMUserException => raised_error
        puts raised_error
      end

    end
  end

end

#
# pocket = PocketAPI.new(ARGV[0])
# evernote = EvernoteAPI.new(ARGV[1]) #pass true as second arg for staging environment

# favs = pocket.retrieve(1)
# list = pocket.process_list(favs)
# evernote.make_all_notes list
# pocket.modify_list list