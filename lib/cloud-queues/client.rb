module CloudQueues
  class Client

    attr_accessor :client_id
    attr_accessor :token
    attr_accessor :tenant

    attr :default_region
    attr :api_host
  
    def initialize(options = {})
      [:username, :api_key].each do |arg|
        raise ArgumentError.new "#{arg} is a required argument." unless options[arg]
      end if options[:token].nil? and options[:tenant].nil?
  
      @client_id = SecureRandom.uuid
  
      options.each_pair {|k, v| instance_variable_set("@#{k}".to_sym, v) }
      authenticate!
    end
  
    def create(name)
      request(method: :put, path: "/queues/#{name}", expects: 201)
      Queue.new(self, name)
    end
  
    def get(name)
      request(method: :head, path: "/queues/#{name}", expects: 204)
      Queue.new(self, name)
    end
  
    def queues
      response = request_all("queues", method: :get, path: "/queues", expects: [200, 204])

      return [] if response.status == 204

      response.body["queues"].map do |queue|
        Queue.new(self, queue["name"])
      end
    end
  
    def authenticate!
      @client = Excon.new("https://identity.api.rackspacecloud.com")
      @base_path = nil

      if @token.nil?
        request = {auth: {"RAX-KSKEY:apiKeyCredentials" => {username: @username, apiKey: @api_key}}}
        response = request(method: :post, path: "/v2.0/tokens", body: request)
        @token = response.body["access"]["token"]["id"]
      else
        # try the current token
        request = {auth: {tenantId: @tenant, token: {id: @token}}}
        response = request(method: :post, path: "/v2.0/tokens", body: request)
      end

      @default_region = response.body["access"]["user"]["RAX-AUTH:defaultRegion"]

      url_type = @internal ? "internalURL" : "publicURL"
      queues = response.body["access"]["serviceCatalog"].select{|service| service["name"] == "cloudQueues" }
      endpoints = queues[0]["endpoints"]

      # default to the account's preferred region
      unless @region
        @region = @default_region
      end

      endpoint = endpoints.select { |endpoint| endpoint["region"] == @region.to_s.upcase }
      raise ArgumentError.new "Region #{@region.to_s.upcase} does not exist!" if endpoint.count == 0
      url = endpoint[0][url_type].split('/')

      @api_host = url[0..2].join('/')
      @base_path = "/" + url[3..-1].join('/')
      @tenant = url[-1]
  
      @client = Excon.new(@api_host, tcp_nodelay: true)
    end
  
    def request(options = {}, second_try = [])
      if options[:body] and options[:body].class != String
        options[:body] = options[:body].to_json
      end
  
      options[:path] = "#{@base_path}#{options[:path]}" unless options[:path].start_with?(@base_path)
  
      options[:headers] ||= {}
      options[:headers]["Content-Type"] = "application/json" if options[:body]
      options[:headers]["Accept"] = "application/json"
      options[:headers]["Client-ID"] = @client_id
      options[:headers]["X-Auth-Token"] = @token if @token
      options[:headers]["X-Project-ID"] = @tenant
  
      options[:expects] ||= 200
  
      puts options if @debug
  
      begin
        response = @client.request(options)
      rescue Excon::Errors::ServiceUnavailable, Excon::Errors::InternalServerError
        raise unless second_try.include?(:servererror)

        # let the API barf once, and wait to retry
        @client.reset
        sleep 0.2
        return request(options, second_try + [:servererror])
      rescue Excon::Errors::SocketError => e
        raise unless e.message.include?("EOFError") or second_try.include?(:socketerror)

        # this happens when the server closes the keep-alive socket and
        # Excon doesn't realize it yet.
        @client.reset
        return request(options, second_try + [:socketerror])
      rescue Excon::Errors::Unauthorized => e
        raise if second_try.include?(:unauth) or @token.nil?

        # Our @token probably expired, re-auth and try again
        @token = nil
        authenticate!
        @client.reset # for good measure
        return request(options, second_try + [:unauth])
      end

      begin
        response.body = JSON.load(response.body) if (response.get_header("Content-Type") || "").include?("application/json")
      rescue
        # the api seems to like to give a json content type for a "204 no content" response
      end

      return response
    end

    def request_all(collection_key, options = {})
      begin
        absolute_limit = options[:query][:limit]
        limit = [absolute_limit, 10].min
        options[:query][:limit] = limit if options[:query][:limit]
      rescue
        absolute_limit = Float::INFINITY
        limit = 10
      end

      first_response = response = request(options)

      if collection_key and first_response.status != 204
        # the next href link will have the query represented in it
        options.delete :query

        collection = first_response.body[collection_key]
        last_links = first_response.body["links"]

        while response.body[collection_key].count >= limit and collection.count < absolute_limit
          next_link = response.body["links"].select{|l| l["rel"] == "next" }[0]["href"]
          options[:path] = set_query_from(options[:path], next_link)

          response = request(options)

          break if response.status == 204
          collection += response.body[collection_key]
          last_links = response.body["links"]
        end

        first_response.body[collection_key] = collection
        first_response.body["links"] = last_links
      end

      return first_response
    end

    private

    # I would just like to comment that this is only necessary because the API does not return the correct
    # href for the next page.  The tenant id (account number) is missing from between the /v1 and /queues.
    def set_query_from(original, new_uri)
      original = URI.parse(original)
      new_query = URI.parse(new_uri).query
      original.query = new_query
      return original.to_s
    end
  
  end
end
