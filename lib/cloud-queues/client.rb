module CloudQueues
  class Client

    attr_accessor :client_id
    attr_accessor :token
    attr_accessor :tenant
  
    def initialize(options = {})
      [:username, :api_key].each do |arg|
        raise ArgumentError.new "#{arg} is a required argument." unless options[arg]
      end if options[:token].nil? and options[:tenant].nil?
  
      @client_id = Socket.gethostname
  
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
      # TODO paging?
      request(method: :get, path: "/queues", expects: [200, 204]).body["queues"].map do |queue|
        Queue.new(self, queue["name"])
      end
    rescue NoMethodError # undefined method `map' for nil:NilClass
      []
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

      url_type = @internal ? "internalURL" : "publicURL"
      queues = response.body["access"]["serviceCatalog"].select{|service| service["name"] == "cloudQueues" }
      endpoints = queues[0]["endpoints"]

      url = if @region.nil?
              # pick the first region
              # TODO when cloud queues goes GA, change this to response.body["access"]["user"]["RAX-AUTH:defaultRegion"]
              endpoints[0][url_type].split('/')
            else
              endpoint = endpoints.select { |endpoint| endpoint["region"] == @region.to_s.upcase }
              raise ArgumentError.new "Region #{@region.to_s.upcase} does not exist!" if endpoint.count == 0
              endpoint[0][url_type].split('/')
            end
  
      host = url[0..2].join('/')
      @base_path = "/" + url[3..-1].join('/')
      @tenant = url[-1]
  
      @client = Excon.new(host)
    end
  
    def request(options = {}, second_try = false)
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
  
      options[:tcp_nodelay] = true if options[:tcp_nodelay].nil?
      options[:expects] ||= 200
  
      puts options if @debug
  
      begin
        response = @client.request(options)
      rescue Excon::Errors::SocketError => e
        raise unless e.message.include?("EOFError") or second_try

        # this happens when the server closes the keep-alive socket and
        # Excon doesn't realize it yet.
        @client.reset
        return request(options, true)
      rescue Excon::Errors::Unauthorized => e
        raise if second_try or @token.nil?

        # Our @token probably expired, re-auth and try again
        @token = nil
        authenticate!
        @client.reset # for good measure
        return request(options, true)
      end

      begin
        response.body = JSON.load(response.body) if (response.get_header("Content-Type") || "").include?("application/json")
      rescue
        # the api seems to like to give a json content type for a "204 no content" response
      end

      return response
    end
  
  end
end
