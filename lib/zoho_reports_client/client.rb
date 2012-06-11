require 'net/https'
require 'cgi'
require 'xmlsimple'

module ZohoReports
  class Client
    def initialize(options)
      [:login_name, :password, :database_name, :api_key].each do |param|
        raise ArgumentError, "No #{param.to_s} specified. Missing argument: #{param.to_s}." unless options.has_key? param
      end

      base_url = 'http://reports.zoho.com'
      uri = URI::parse(base_url)
      @http = Net::HTTP.new(uri.host, uri.port)

      @login_name = options[:login_name]
      @password = options[:password]
      @database_name = options[:database_name]
      @api_key = options[:api_key]
      @ticket = self.login(@login_name, @password)
    end

    def login(login_name, login_password)
      login_base_url = 'https://accounts.zoho.com'
      url = "#{login_base_url}/login?servicename=ZohoReports&FROM_AGENT=true&LOGIN_ID=#{login_name}&PASSWORD=#{login_password}"
      uri = URI.parse(url)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true if uri.scheme == 'https'
      get = Net::HTTP::Get.new(url)
      response = http.request(get)
      params = { }

      response.body.each_line do |line|
        if line.include? '='
          line.chomp!
          key, value = line.split('=')
          params[key] = value
        end
      end
      raise ArgumentError, "No ticket specified. Missing argument: ticket." unless params.has_key? 'TICKET'

      params['TICKET']
    end

    def zoho_find_by_sql(database_name, table_name, sql = '')
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

    def zoho_create(database_name, table_name, row_data = { })
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

    def zoho_update(database_name, table_name, conditions, new_data = { })
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


    def zoho_delete(database_name, table_name, conditions = '')
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

    # Add & update data in bulk from a CSV file.
    # See: https://zohoreportsapi.wiki.zoho.com/Importing-CSV-File.html
    #
    # table_name  - The String name of the table to import data into.
    # csv_file_name - The String full file name with path of the CSV file to import.
    # options - The Hash options/params to include in the API request (default values listed; see
    #           above URL for full list):
    #           :ZOHO_AUTO_IDENTIFY - Default: 'true'
    #           :ZOHO_ON_IMPORT_ERROR - Default: 'SKIPROW'
    #           :ZOHO_CREATE_TABLE - Default: 'true'
    #           :ZOHO_IMPORT_TYPE - Default: 'TRUNCATEADD'
    def migrate(table_name, csv_file_name, options = { })
      result = false
      if File.exist? csv_file_name
        begin
          csv_reader = File.open(csv_file_name)
          csv_data = csv_reader.read
          csv_reader.close

          params = { :ZOHO_AUTO_IDENTIFY => 'true', :ZOHO_ON_IMPORT_ERROR => 'SKIPROW',
                     :ZOHO_CREATE_TABLE => 'true', :ZOHO_IMPORT_TYPE => 'TRUNCATEADD',
                     :ZOHO_IMPORT_DATA => csv_data }

          query = params.merge(options).to_query_string(include_question_mark = false)
          response = zoho_action(:migrate, @database_name, table_name, query)

          if response.keys.include? 'result'
            result = true
          elsif response.keys.include? 'error'
            #logger.error create_response["error"]["message"]
            result = false
          else
            result = false
          end
        rescue => exception
          #logger.error exception.message
          result = false
        end
      end
      result
    end

    protected

    def zoho_action(action, database_name, table_name, data = '')
      actions = { :find => 'EXPORT', :create => 'ADDROW', :update => 'UPDATE', :delete => 'DELETE', :migrate => 'IMPORT' }
      raise ArgumentError, "No #{action.to_s} action available. Must be one of: #{actions.values.map { |v| v.to_s }.uniq.sort.join(', ')}" unless actions.keys.include? action

      param = case action
        when :find
          "ZOHO_SQLQUERY="
        when :delete
          "ZOHO_CRITERIA="
        else
          ""
      end

      post_data = param + data
      zoho_response = zoho_request(database_name, table_name, 'POST', { 'ZOHO_ACTION' => actions[action] }, post_data)
      result = handle_response(zoho_response)
      result
    end

    def zoho_request(database_name, table_name, method, params, *arguments)
      params.merge!({
                        'ZOHO_ERROR_FORMAT' => 'XML',
                        'ZOHO_OUTPUT_FORMAT' => 'XML',
                        'ZOHO_API_KEY' => @api_key,
                        'ticket' => @ticket,
                        'ZOHO_API_VERSION' => '1.0'
                    })

      base_url = "http://reports.zoho.com/api"
      url = "#{base_url}/#{@login_name}/#{database_name}/#{table_name}#{params.to_query_string}"

      response = @http.send_request(method, url, *arguments)
      raise "HTTP Error: #{response.code.to_i}" unless (200...400).include? response.code.to_i
      response
    end

    def handle_response(response)
      response_data = XmlSimple.xml_in(response.body, 'ForceArray' => false, 'KeepRoot' => true)

      raise "Unexpected Zoho Reports API Response" unless response_data.keys.include? "response"
      query_result = response_data["response"]
      query_result
    end
  end
end
