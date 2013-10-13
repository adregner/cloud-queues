module CloudQueues
  class Queue

    attr_accessor :default_ttl

    attr_reader :name, :client

    def initialize(client, name)
      @client = client
      @name = name

      # TODO maybe make these defaults on the client or something, this isn't going
      # to always work out the way we want
      @default_ttl = 1209600 # 14 days, server max

      @default_claim_ttl = 43200 # 12 hours, server max
      @default_claim_grace = 300 # 5 minutes, arbitrary
    end

    def messages(options = {})
      if options[:ids]
        raise ArgumentError.new "Only 20 or less message IDs may be specified" if options[:ids].count > 20
        allowed_query = %w[ids claim_id]
      else
        allowed_query = %w[marker limit echo include_claimed]
      end

      options = options.select { |opt| allowed_query.include?(opt.to_s) }

      # Excon likes to CGI.escape values in a query hash, so this has to be handled manually
      if options[:ids]
        query = "?ids=#{options.delete(:ids).join(',')}"
        options.each_pair do |key, value|
          query << "&#{key}=#{CGI.escape(value)}"
        end
        options = query
      end

      response = @client.request_all(options.class == String ? nil : "messages",
                                     method: :get, path: "#{path}/messages", expects: [200, 204], query: options)
      return [] if response.status == 204
      response.body.class == Hash ? process_messages(response.body["messages"]) : process_messages(response.body)
    end

    def get(id, options = {})
      options = options[:claim_id] ? {claim_id: options[:claim_id]} : {}
      msgs = @client.request(method: :get, path: "#{path}/messages/#{id}", query: options)
      process_messages([msgs.body])[0]
    end

    def put(*msgs)
      raise ArgumentError.new("Only 10 or less messages may be given at once") if msgs.count > 10

      msgs = msgs.map do |message|
        begin
          if message.class == Message
            message.to_hash
          elsif message[:body] or message["body"]
            {
              ttl: message[:ttl] || message["ttl"] || @default_ttl,
              body: message[:body] || message["body"],
            }
          else
            { ttl: @default_ttl, body: message }
          end
        rescue
          { ttl: @default_ttl, body: message }
        end
      end

      # TODO this should probably do something with a body["partial"] == true response
      resources = @client.request(method: :post, path: "#{path}/messages", body: msgs, expects: 201).body["resources"]
      resources.map { |resource| URI.parse(resource).path.split('/')[-1] }
    end

    def claim(options = {})
      query = options[:limit] ? {limit: options[:limit]} : {}
      body = {
        ttl: options[:ttl] || options["ttl"] || @default_claim_ttl,
        grace: options[:grace] || options["grace"] || @default_claim_grace,
      }
      response = @client.request(method: :post, path: "#{path}/claims", body: body, query: query, expects: [201, 204])
      return [] if response.status == 204
      claim_id = URI.parse(response.get_header("Location")).path.split('/')[-1]
      process_claim(claim_id, response.body)
    end

    def delete_messages(*ids)
      query = "?ids=#{ids.join(',')}"
      @client.request(method: :delete, path: "#{path}/messages", expects: 204, query: query) && true
    end

    def delete!
      @client.request(method: :delete, path: "#{path}", expects: 204) && true
    end
  
    def [](key)
      metadata[key]
    end
  
    def []=(key, value)
      new_data = metadata
      new_data[key] = value
      @client.request(method: :put, path: "#{path}/metadata", body: new_data, expects: 204) && true
    end
  
    def metadata
      @client.request(method: :get, path: "#{path}/metadata").body
    end
  
    def metadata=(new_data)
      @client.request(method: :put, path: "#{path}/metadata", body: new_data, expects: 204) && true
    end

    def stats
      @client.request(method: :get, path: "#{path}/stats").body
    end

    def stat(name)
      stats["messages"][name.to_s]
    end

    def claimed; stat(:claimed); end
    def free; stat(:free); end
    def total; stat(:total); end
    def newest; stat(:newest); end
    def oldest; stat(:oldest); end

    def path
      "/queues/#{@name}"
    end

    private

    def process_messages(msgs)
      msgs.map { |message| Message.new(self, message) }
    end

    def process_claim(claim_id, msgs)
      Claim.new(self, claim_id, process_messages(msgs))
    end

  end
end
