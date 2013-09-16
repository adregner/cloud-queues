module RackspaceQueues
  class Queue

    attr_accessor :default_ttl

    attr_reader :name

    def initialize(client, name)
      @client = client
      @name = name

      @default_ttl = 1209600 # 14 days, server max
    end

    def messages(options = {})
      if options[:ids]
        allowed_query = %w[ids claim_id]
        options[:ids] = options[:ids].join(',') if options[:ids].class == Array
      else
        allowed_query = %w[marker limit echo include_claimed]
      end

      options = options.select { |opt| allowed_query.include?(opt.to_s) }
      response = @client.request(method: :get, path: "#{path}/messages", expects: [200, 204], query: options)
      return [] if response.code == 204
      process_messages(response.body["messages"])
    end

    def get(id, options = {})
      options = options[:claim_id] ? {claim_id: options[:claim_id]} : {}
      msgs = @client.request(method: :get, path: "#{path}/messages/#{id}", query: options)
      process_messages([msgs.body])[0]
    end

    def put(*msgs)
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
      options = options.select { |opt| %w[ttl grace].include?(opt.to_s) }
      response = @client.request(method: :post, path: "#{path}/claims", body: options, query: query, expects: [200, 204])
      return [] if response.code == 204
      claim_id = URI.parse(response.get_header("Location")).path.split('/')[-1]
      process_claim(claim_id, response.body)
    end

    def delete_messages(*ids)
      ids = options[:ids].join(',')
      @client.request(method: :delete, path: "#{path}/messages", expects: 204, query: {ids: ids}) && true
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
