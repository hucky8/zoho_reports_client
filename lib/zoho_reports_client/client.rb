require 'net/https'
require 'cgi'
require 'xmlsimple'
require 'net/http/post/multipart'

module ZohoReports
  class Client
    def initialize(options)
      [:login_name, :password, :database_name, :auth_token].each do |param|
        raise ArgumentError, "No #{param.to_s} specified. Missing argument: #{param.to_s}." unless options.has_key? param
      end

      base_url = 'https://reportsapi.zoho.com'
      uri = URI::parse(base_url)
      @http = Net::HTTP.new(uri.host, uri.port)

      @login_name = options[:login_name]
      @password = options[:password]
      @database_name = options[:database_name]
      @auth_token = options[:auth_token]
      
    end


    def find_by_sql(database_name, table_name, sql = '')
      begin
        find_response = zoho_action(:find, database_name, table_name, CGI::escape(sql))
        if find_response.keys.include? "result"
          find_result = find_response["result"]
        elsif find_response.keys.include? "error"
          #logger.error find_response["error"]["message"]
          find_result = { }
        else
          find_result = nil
        end
      rescue => exception
        #logger.error exception.message
        find_result = nil
      end
      find_result
    end

    def create(database_name, table_name, row_data = { })
      row_data = row_data.to_query_string(include_question_mark = false)

      begin
        create_response = zoho_action(:create, database_name, table_name, row_data)
        if create_response.keys.include? "result"
          row_created = true
        elsif create_response.keys.include? "error"
          #logger.error create_response["error"]["message"]
          row_created = false
        else
          row_created = false
        end
      rescue => exception
        #logger.error exception.message
        row_created = false
      end
      row_created
    end

    def update(database_name, table_name, conditions, new_data = { })
      update_conditions = "&ZOHO_CRITERIA=" + "(#{CGI::escape(conditions)})"
      update_data = new_data.to_query_string(include_question_mark = false) + update_conditions

      begin
        update_response = zoho_action(:update, database_name, table_name, update_data)
        if update_response.keys.include? "result"
          row_updated = true
        elsif update_response.keys.include? "error"
          #logger.error update_response["error"]["message"]
          row_updated = false
        else
          row_updated = false
        end
      rescue => exception
        #logger.error exception.message
        row_updated = false
      end
      row_updated
    end


    def delete(database_name, table_name, conditions = '')
      begin
        delete_response = zoho_action(:delete, database_name, table_name, CGI::escape(conditions))
        if delete_response.keys.include? "result"
          row_deleted = true
        elsif delete_response.keys.include? "error"
          #logger.error delete_response["error"]["message"]
          row_deleted = false
        else
          row_deleted = false
        end
      rescue => exception
        #logger.error exception.message
        row_deleted = false
      end
      row_deleted
    end

    # Adds & updates data in bulk from a CSV file.
    # See: https://zohoreportsapi.wiki.zoho.com/Importing-CSV-File.html
    #
    # table_name  - The String name of the table to import data into.
    # csv_file_name - The String full file name with path of the CSV file to import.
    # url_params - The Hash url_params/url_params to include in the API request (default values listed; see
    #           above URL for full list):
    #           :ZOHO_AUTO_IDENTIFY - Default: 'true'
    #           :ZOHO_ON_IMPORT_ERROR - Default: 'SETCOLUMNEMPTY'
    #           :ZOHO_CREATE_TABLE - Default: 'true'
    #           :ZOHO_IMPORT_TYPE - Default: 'TRUNCATEADD'
    def import(table_name, csv_file_name, params = { })
      result = false
      if File.exist? csv_file_name
        begin
          params.reverse_merge!(:ZOHO_AUTO_IDENTIFY => 'true', :ZOHO_ON_IMPORT_ERROR => 'SETCOLUMNEMPTY',
                                :ZOHO_CREATE_TABLE => 'true', :ZOHO_IMPORT_TYPE => 'TRUNCATEADD',
                                :ZOHO_FILE => UploadIO.new(csv_file_name, 'text/csv'))
          response = zoho_action(:import, @database_name, table_name, params)

          if response.keys.include? 'result'
            result = true
          elsif response.keys.include? 'error'
            logger.error response["error"]["message"] if defined?(logger)
            result = false
          else
            result = false
          end
        rescue Exception => e
          logger.error e.message if defined?(logger)
          result = false
        end
      end
      result
    end

    private

    # Makes a login or logout POST request, and converts the response to a Hash.
    def authentication_request(url, params)
      uri = URI.parse(url)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true if uri.scheme == 'https'

      post = Net::HTTP::Post.new(url)
      post.set_form_data(params)

      response = http.request(post)
      handle_authentication_response(response)
    end

    # Converts an authentication request's response into a Hash and returns it.
    def handle_authentication_response(response)
      result = { }

      response.body.each_line do |line|
        if line.include? '='
          line.chomp!
          key, value = line.split('=')
          result[key] = value
        end
      end

      result
    end

    # Sets up a Zoho API call, makes the request and handles the response.
    #
    # action  - The Symbol API action to call. Must be one of the following: :find, :create,
    #           :update, :delete, or :import
    # database_name - The String name of the database to invoke an API action for.
    # table_name  - The String name of the table in the database the action is targeting.
    # params  - The Hash of data parameters to send as the body of the request.
    def zoho_action(action, database_name, table_name, params = { })
      actions = { :find => 'EXPORT',
                  :create => 'ADDROW',
                  :update => 'UPDATE',
                  :delete => 'DELETE',
                  :import => 'IMPORT' }
      raise ArgumentError, "No #{action.to_s} action available. Must be one of: #{actions.values.map { |v| v.to_s }.uniq.sort.join(', ')}" unless actions.keys.include? action

      if action == :find
        params = { :ZOHO_SQLQUERY => params }
      elsif action == :delete
        params = { :ZOHO_CRITERIA => params }
      end

      zoho_response = zoho_request(database_name, table_name, action == :import,
                                   { :ZOHO_ACTION => actions[action] }, params)
      handle_response(zoho_response)
    end

    # Actually makes a request to the Zoho API.
    #
    # database_name - The String name of the database to invoke an API action for.
    # table_name  - The String name of the table in the database the action is targeting.
    # multipart - The Boolean true or false whether the request should be multipart (e.g. it includes
    #             a file, such as an :import action).
    # url_params  - The Hash of params to include on the URL (not in the body)
    # params  - The Hash of params to include in the body of the POST request.
    def zoho_request(database_name, table_name, multipart, url_params, params)
      url_params.merge!({
                            :ZOHO_ERROR_FORMAT => 'XML',
                            :ZOHO_OUTPUT_FORMAT => 'XML',
                            :authtoken => @auth_token,
                            :ZOHO_API_VERSION => '1.0'
                        })

      base_url = "https://reportsapi.zoho.com/api"
      url = "#{base_url}/#{@login_name}/#{database_name}/#{table_name}?#{url_params.to_query}"
      #https://reportsapi.zoho.com/api/<zohologinemailaddress>/<databasename>/<tablename or reportname>

      if multipart
        request = Net::HTTP::Post::Multipart.new(url, params)
      else
        request = Net::HTTP::Post.new(url)
        request.set_form_data(params)
      end

      response = @http.start do |http|
        http.request(request)
      end
      raise "HTTP Error: #{response.code.to_i}" unless (200...400).include? response.code.to_i
      response
    end

    def handle_response(response)
      response_data = XmlSimple.xml_in(response.body, 'ForceArray' => false, 'KeepRoot' => true)

      raise "Unexpected Zoho Reports API Response" unless response_data.keys.include? "response"
      response_data["response"]
    end
  end
end
